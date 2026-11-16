pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import "../../common" as Common
import "BrightnessLogic.js" as Logic

Singleton {
  id: root
  property var monitors: []
  property var outputNames: []
  property var requestedValues: ({})
  readonly property alias monitorModel: displayModel
  property string error: ""
  property var queued: ({})
  property var adjusting: ({})
  property string pending: ""
  property var externalReadings: ({})
  property double readStartedAt: 0
  ListModel { id: displayModel }
  function reconcile(rows): void {
    rows = rows.map(row => {
      const event = externalReadings[row.device];
      return row.backend === "backlight" && event && event.time >= readStartedAt
        ? Object.assign({}, row, {percent: event.percent}) : row;
    });
    // Preserve delegates and pointer grabs; only hotplug changes their identity.
    for (let i = displayModel.count - 1; i >= 0; i--)
      if (!rows.some(row => row.name === displayModel.get(i).name)) displayModel.remove(i);
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      let index = -1;
      for (let j = 0; j < displayModel.count; j++) if (displayModel.get(j).name === row.name) { index = j; break; }
      if (index < 0) displayModel.insert(i, row);
      else {
        if (index !== i) displayModel.move(index, i, 1);
        if (!adjusting[row.name]) displayModel.set(i, row);
      }
    }
    // Display selectors depend only on output names, not brightness readbacks.
    const names = rows.map(row => row.name);
    if (JSON.stringify(outputNames) !== JSON.stringify(names)) outputNames = names;
    if (JSON.stringify(monitors) !== JSON.stringify(rows)) monitors = rows;
  }
  function externalBrightness(device, percent): void {
    externalReadings = Object.assign({}, externalReadings, {[device]: {percent: percent, time: Date.now()}});
    for (let i = 0; i < displayModel.count; i++) {
      const row = displayModel.get(i);
      if (row.backend === "backlight" && row.device === device && row.available
          && !adjusting[row.name] && pending !== row.name && !(row.name in queued)) displayModel.setProperty(i, "percent", percent);
    }
    monitors = monitors.map(row => row.backend === "backlight" && row.device === device && row.available
      && !adjusting[row.name] && pending !== row.name && !(row.name in queued)
      ? Object.assign({}, row, {percent: percent}) : row);
  }
  function beginAdjustment(name): void { adjusting[name] = true; }
  function cancelAdjustment(name): void { delete adjusting[name]; }
  function endAdjustment(name, value): void { delete adjusting[name]; setBrightness(name, value); }
  function setBrightness(name, value): void {
    const target = Math.max(0, Math.min(100, Math.round(value)));
    queued[name] = target;
    requestedValues = Object.assign({}, requestedValues, {[name]: target});
    next();
  }
  property bool reading: false
  property var backlights: []
  property var connectors: []
  Common.Command { id: runner }
  function resolveAll(done) {
    runner.run(["hyprctl", "-j", "monitors"], (code, output) => {
      let displays;
      try { if (code !== 0) throw new Error("Monitor query failed."); displays = JSON.parse(output); }
      catch (e) { error = String(e); done([]); return; }
      runner.run(["ls", "-1", "/sys/class/backlight"], (code, output) => {
        backlights = code === 0 ? output.trim().split("\n").filter(n => /^[A-Za-z0-9_.-]+$/.test(n)) : [];
        runner.run(["ls", "-1", "/sys/class/drm"], (code, output) => {
          connectors = code === 0 ? output.trim().split("\n").filter(n => /^card[0-9]+-.+$/.test(n)).map(n => "/sys/class/drm/" + n) : [];
          const rows = [];
          function step(index) {
            if (index === displays.length) { done(rows); return; }
            const display = displays[index];
            const mapping = Logic.resolve(display.name, displays, backlights, connectors);
            const row = Object.assign({name: display.name, available: false, percent: 0, reason: "Brightness unavailable."}, mapping);
            function read() {
              if (!row.device) { rows.push(row); step(index + 1); return; }
              readValue(row, (ok, value) => {
                row.available = ok; row.percent = ok ? value : 0;
                row.reason = ok ? "" : "Cannot read brightness; check permissions and dependencies.";
                rows.push(row); step(index + 1);
              });
            }
            if (mapping.connector) runner.run(["readlink", "-f", "--", mapping.connector + "/ddc"], (code, output) => {
              const match = /\/i2c-([0-9]+)$/.exec(output.trim());
              row.device = code === 0 && match ? match[1] : "";
              read();
            }); else read();
          }
          step(0);
        });
      });
    });
  }
  function readValue(row, done) {
    if (row.backend === "backlight") runner.run(["brightnessctl", "-d", row.device, "get"], (code, output) => {
      if (code !== 0) { done(false, 0); return; }
      const current = output.trim();
      runner.run(["brightnessctl", "-d", row.device, "max"], (code, output) => {
        try { if (code !== 0) throw new Error(); done(true, Logic.percentage(current, output.trim())); }
        catch (_) { done(false, 0); }
      });
    });
    else runner.run(["ddcutil", "--bus", row.device, "getvcp", "10", "--terse"], (code, output) => {
      try { const fields = output.trim().split(/\s+/); if (code !== 0 || fields[2] !== "C") throw new Error(); done(true, Logic.percentage(fields[3], fields[4])); }
      catch (_) { done(false, 0); }
    });
  }
  function next() {
    if (reading || runner.running || cadence.running) return;
    const names = Object.keys(queued);
    if (!names.length) return;
    pending = names[0];
    const name = pending, value = queued[name]; delete queued[name];
    reading = true;
    // Re-resolve on every write. A hotplug can invalidate a previously safe map.
    resolveAll(rows => {
      const row = rows.find(row => row.name === name && row.available);
      if (!row) { error = "Display disconnected or brightness mapping changed."; finish(); return; }
      const args = row.backend === "backlight" ? ["brightnessctl", "-d", row.device, "set", value + "%"]
        : ["ddcutil", "--bus", row.device, "setvcp", "10", String(value)];
      runner.run(args, (code, out, failure) => {
        error = code === 0 ? "" : failure || "Brightness update failed.";
        readValue(row, (ok, actual) => {
          if (ok) { row.percent = actual; reconcile(rows); }
          finish();
        });
      });
    });
    function finish() {
      reading = false; pending = "";
      const remaining = Object.assign({}, requestedValues);
      if (!(name in queued)) delete remaining[name]; requestedValues = remaining;
      cadence.restart();
    }
  }
  function refresh() {
    if (reading || runner.running || Object.keys(adjusting).length || Object.keys(queued).length) return;
    reading = true; readStartedAt = Date.now();
    resolveAll(rows => { reconcile(rows); reading = false; next(); });
  }
  Timer { id: cadence; interval: 60; onTriggered: root.next() }
  Timer { interval: 1000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
  Connections { target: Quickshell; function onScreensChanged() { root.refresh(); } }
}
