import QtQuick
import Quickshell
import "../../common" as Common
import "CaptureLogic.js" as Logic

Scope {
  id: root
  property string source: ""
  property string sink: ""
  property string mode: "none"
  property var modules: []
  property var profiles: []
  property bool autoswitch: false
  property bool bluetoothInput: false
  property bool cancelled: false
  property var done: null
  property var waitDone: null
  property string waitKind: ""
  property string waitName: ""
  property int retries: 0
  Common.Command { id: runner }
  Timer { id: waitRetry; interval: 100; onTriggered: root.checkNode() }
  function run(args, callback) {
    runner.run(args, (code, output, error) => {
      if (cancelled) { fail("Capture cancelled."); return; }
      callback(code, output, error);
    });
  }
  function fail(message) { const cb = done; done = null; if (cb) cb(message); }
  function prepare(audio, callback) {
    mode = audio; done = callback; cancelled = false; source = ""; modules = []; profiles = []; autoswitch = false; bluetoothInput = false;
    if (audio === "none") { fail(""); return; }
    run(["pactl", "get-default-sink"], (code, output) => {
      if (code !== 0 || !output.trim()) { fail("No default audio output."); return; }
      sink = output.trim();
      if (audio === "system") playback(() => { source = sink + ".monitor"; fail(""); });
      else microphone();
    });
  }
  function microphone() {
    run(["pactl", "get-default-source"], (code, output) => {
      source = output.trim();
      if (code !== 0 || !source || source.endsWith(".monitor")) { fail("Select a microphone in the Sound panel."); return; }
      run(["pactl", "get-source-mute", source], (code, output) => {
        if (code !== 0 || /yes/.test(output)) { fail("Unmute the microphone before recording."); return; }
        bluetoothInput = source.startsWith("bluez_input.");
        if (bluetoothInput) pinMicrophone(() => mix());
        else playback(() => mix());
      });
    });
  }
  function card(name, callback) {
    run(["pactl", "--format=json", "list", "cards"], (code, output) => {
      try {
        const row = JSON.parse(output).find(row => row.name === name);
        if (code !== 0 || !row || typeof row.active_profile !== "string") throw new Error();
        callback(row);
      } catch (_) { fail("Bluetooth audio card unavailable."); }
    });
  }
  function setProfile(card, choices, callback) {
    if (!choices.length) { fail("No compatible Bluetooth profile."); return; }
    // Journal before mutation so cleanup also handles an interrupted request.
    if (!profiles.some(row => row.name === card.name)) profiles.push({name: card.name, profile: card.active_profile});
    run(["pactl", "set-card-profile", card.name, choices[0]], code => {
      if (code === 0) callback(); else setProfile(card, choices.slice(1), callback);
    });
  }
  function pinMicrophone(callback) {
    card(Logic.bluetoothCard(source), row => {
      run(["wpctl", "settings", "bluetooth.autoswitch-to-headset-profile"], (code, output) => {
        const enabled = code === 0 && /\btrue\b/.test(output);
        function pin() {
          if (row.active_profile.startsWith("headset-head-unit")) waitNode(source, "sources", callback);
          else setProfile(row, ["headset-head-unit", "headset-head-unit-cvsd"], () => waitNode(source, "sources", callback));
        }
        if (enabled) {
          autoswitch = true;
          run(["wpctl", "settings", "bluetooth.autoswitch-to-headset-profile", "false"], code => {
            if (code !== 0) { fail("Cannot pin Bluetooth microphone policy."); return; }
            pin();
          });
        } else pin();
      });
    });
  }
  function playback(callback) {
    if (!sink.startsWith("bluez_output.")) { callback(); return; }
    card(Logic.bluetoothCard(sink), row => {
      if (row.active_profile.startsWith("a2dp-sink")) { callback(); return; }
      run(["pactl", "--format=json", "list", "sources"], (code, output) => {
        let sources;
        try { if (code !== 0) throw new Error(); sources = JSON.parse(output); }
        catch (_) { fail("Cannot check Bluetooth microphone use."); return; }
        const microphone = sources.find(s => Logic.bluetoothCard(s.name) === row.name);
        run(["pactl", "--format=json", "list", "source-outputs"], (code, output) => {
          try {
            if (code !== 0) throw new Error();
            if (microphone && JSON.parse(output).some(stream => Number(stream.source) === Number(microphone.index))) { callback(); return; }
          } catch (_) { fail("Cannot check Bluetooth microphone use."); return; }
          setProfile(row, ["a2dp-sink", "a2dp-sink-sbc", "a2dp-sink-sbc_xq"], () => {
            run(["pactl", "get-default-sink"], (code, output) => {
              if (code !== 0) { fail("Bluetooth output did not appear."); return; }
              sink = output.trim(); waitNode(sink, "sinks", callback);
            });
          });
        });
      });
    });
  }
  function waitNode(name, kind, callback) { waitName = name; waitKind = kind; waitDone = callback; retries = 30; checkNode(); }
  function checkNode() {
    run(["pactl", "--format=json", "list", waitKind], (code, output) => {
      let found = false;
      try { found = code === 0 && JSON.parse(output).some(row => row.name === waitName); } catch (_) {}
      if (found) { const cb = waitDone; waitDone = null; cb(); }
      else if (--retries > 0) waitRetry.restart();
      else fail("Bluetooth audio node did not appear.");
    });
  }
  function loadModule(args, callback) {
    // Record module IDs even when cancellation arrived while pactl was running.
    runner.run(["pactl", "load-module"].concat(args), (code, output) => {
      const id = output.trim();
      if (code === 0 && /^\d+$/.test(id)) modules.push(id);
      else { fail("Cannot create recording audio mix."); return; }
      if (cancelled) { fail("Capture cancelled."); return; }
      callback();
    });
  }
  function mix() {
    if (mode !== "both") { fail(""); return; }
    const name = "astral_recording_" + Date.now();
    waitNode(sink, "sinks", () => loadModule(["module-null-sink", "sink_name=" + name], () =>
      loadModule(["module-loopback", "source=" + source, "sink=" + name, "latency_msec=30", "source_dont_move=true", "sink_dont_move=true"], () =>
        loadModule(["module-loopback", "source=" + sink + ".monitor", "sink=" + name, "latency_msec=30", "source_dont_move=true", "sink_dont_move=true"], () => {
          source = name + ".monitor"; fail("");
        }))));
  }
  function cleanup(callback) {
    waitRetry.stop();
    const tasks = modules.slice().reverse().map(id => ["pactl", "unload-module", id])
      .concat(profiles.slice().reverse().map(row => ["pactl", "set-card-profile", row.name, row.profile]));
    if (autoswitch) tasks.push(["wpctl", "settings", "bluetooth.autoswitch-to-headset-profile", "true"]);
    let failure = "";
    function next() {
      if (!tasks.length) { modules = []; profiles = []; autoswitch = false; callback(failure); return; }
      runner.run(tasks.shift(), (code, output, error) => { if (code !== 0) failure = error || "Could not restore recording audio resources."; next(); });
    }
    next();
  }
}
