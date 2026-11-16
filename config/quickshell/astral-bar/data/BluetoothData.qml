pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  property var adapters: []
  property var devices: []
  property string selected: ""
  property int operationTimeout: 30000
  property int pairingTimeout: 120000
  property bool available: false
  property bool powered: false
  property bool scanning: false
  property int viewers: 0
  property string error: ""
  property string pending: ""
  readonly property bool busy: pending !== ""
  property string target: ""
  property string operation: ""
  property string prompt: ""
  property string promptKind: ""
  property string buffer: ""
  property string infoAddress: ""
  property bool controllerInfo: false
  property string controllerAddress: ""
  property int consumed: 0
  property bool stopping: false
  readonly property string state: !available ? "Bluetooth service unavailable" : !adapters.length ? "No Bluetooth adapter" : !powered ? "Bluetooth is off" : pending || (scanning ? "Scanning…" : "Ready")

  function valid(address) { return /^([0-9A-F]{2}:){5}[0-9A-F]{2}$/i.test(address); }
  function send(command) { if (session.running) session.write(command + "\n"); }
  function update(address, values) {
    if (!valid(address)) return;
    let list = devices.slice();
    let index = list.findIndex(d => d.address === address);
    if (index < 0) { index = list.length; list.push({address:address, name:address, paired:false, trusted:false, connected:false}); }
    list[index] = Object.assign({}, list[index], values);
    devices = list;
  }
  function start() {
    if (session.running) return;
    stopping = false; consumed = 0; buffer = ""; infoAddress = "";
    session.running = true; startup.restart();
  }
  function refresh() {
    if (!session.running || promptKind || busy) return;
    send("list"); send("show"); send("devices");
    devices.forEach(d => send("info " + d.address));
  }
  function selectAdapter(address) {
    if (busy || !valid(address) || address === selected) return;
    stopScan(); selected = address; devices = []; powered = false;
    send("select " + address); refresh();
  }
  function begin(kind, address, label) {
    if (busy || !available || !selected || (address && !valid(address))) return false;
    operation = kind; target = address; pending = label; error = "";
    deadline.interval = kind === "pair" ? pairingTimeout : operationTimeout; deadline.restart();
    return true;
  }
  function finish(message = "") {
    deadline.stop(); error = message; pending = ""; operation = ""; target = "";
    prompt = ""; promptKind = ""; refresh();
  }
  function setPower(value) {
    if (begin("power", "", "Changing power…")) { stopScan(); send("power " + (value ? "on" : "off")); }
  }
  function scan() {
    if (!powered || busy || scanning) return;
    error = ""; send("scan on"); scanning = true; scanDeadline.restart();
  }
  function stopScan() { scanDeadline.stop(); if (scanning) send("scan off"); scanning = false; }
  function connectDevice(address) {
    const device = devices.find(d => d.address === address);
    if (!powered || !device || device.connected) return;
    if (!begin(device.paired ? "connect" : "pair", address, device.paired ? "Connecting…" : "Pairing…")) return;
    stopScan();
    if (operation === "pair") send("agent KeyboardDisplay");
    else send(operation + " " + address);
  }
  function disconnectDevice(address) {
    if (begin("disconnect", address, "Disconnecting…")) send("disconnect " + address);
  }
  function forget(address) {
    if (devices.some(d => d.address === address) && begin("remove", address, "Forgetting…")) send("remove " + address);
  }
  function answer(value) {
    if (!promptKind || !busy) return;
    if (promptKind === "confirm" && !["yes", "no"].includes(value)) return;
    if (promptKind === "passkey" && !/^\d{1,6}$/.test(value)) return;
    if (promptKind === "pin" && (!value.length || value.length > 16 || /[\r\n\x00]/.test(value))) return;
    buffer = ""; send(value); prompt = ""; promptKind = "";
  }
  function cancel() {
    // Terminating this agent rejects outstanding requests, including PIN input.
    if (!busy) return;
    error = "Pairing or operation canceled"; shutdown();
    if (viewers > 0) restart.restart();
  }
  function shutdown() {
    stopScan(); deadline.stop(); stopping = true;
    pending = ""; operation = ""; prompt = ""; promptKind = ""; target = "";
    available = false; if (session.running) session.signal(15);
  }
  function line(text) {
    let match;
    if ((match = text.match(/(?:\[NEW\] )?Controller ((?:[\dA-F]{2}:){5}[\dA-F]{2}) (.*)/i))) {
      const address = match[1];
      if (!adapters.some(a => a.address === address)) adapters = adapters.concat([{address:address, name:match[2].replace(/ \[default\]$/, "")}]);
      if (!selected) selected = address;
      available = true; controllerInfo = true; controllerAddress = address; infoAddress = "";
    } else if ((match = text.match(/(?:\[NEW\] )?Device ((?:[\dA-F]{2}:){5}[\dA-F]{2})(?: (.*))?/i)) && !text.includes("[CHG]") && !text.includes("[DEL]")) {
      infoAddress = match[1]; controllerInfo = false;
      const known = devices.some(d => d.address === infoAddress);
      update(infoAddress, match[2] && !match[2].startsWith("(") ? {name:match[2]} : {});
      if (!known && !busy) send("info " + infoAddress);
    }
    if ((match = text.match(/\[DEL\] Device (\S+)/))) devices = devices.filter(d => d.address !== match[1]);
    if (text.includes("[DEL] Controller")) { adapters = []; devices = []; selected = ""; powered = false; }
    if ((match = text.match(/\[CHG\] Device (\S+) (\w+): (.*)/))) propertyValue(match[1], match[2], match[3]);
    else if ((match = text.match(/^\s+(Name|Alias|Paired|Bonded|Trusted|Connected): (.*)/)) && infoAddress) propertyValue(infoAddress, match[1], match[2]);
    if (((controllerInfo && controllerAddress === selected) || text.includes("[CHG] Controller " + selected + " ")) && /Powered: (yes|no)/.test(text)) powered = text.includes("Powered: yes");
    if (text.includes("Discovering: no")) scanning = false;
    if (/No default controller/.test(text)) { powered = false; selected = ""; }
    if (/Failed|not available|not ready|not found|AuthenticationCanceled|AuthenticationRejected/.test(text)) {
      const message = text.replace(/\[.*?\]> /g, "").slice(0, 240);
      if (busy) finish(message); else error = message;
    }
    if (operation === "pair" && text.includes("Pairing successful")) {
      update(target, {paired:true}); operation = "trust"; send("trust " + target);
    } else if (operation === "trust" && text.includes("trust succeeded")) {
      operation = "connect"; pending = "Connecting…"; send("connect " + target);
    } else if (operation === "connect" && text.includes("Connection successful")) {
      update(target, {connected:true}); finish();
    } else if (operation === "disconnect" && /Disconnection successful|Successful disconnected/.test(text)) {
      update(target, {connected:false}); finish();
    } else if (operation === "remove" && text.includes("Device has been removed")) {
      devices = devices.filter(d => d.address !== target); finish();
    } else if (operation === "power" && text.includes("Changing power") && text.includes("succeeded")) finish();
    if (/Agent registered|Agent is already registered/.test(text)) {
      available = true;
      if (operation === "pair") send("pair " + target);
    }
  }
  function propertyValue(address, key, value) {
    const keys = {Name:"name", Alias:"name", Paired:"paired", Bonded:"paired", Trusted:"trusted", Connected:"connected"};
    if (!keys[key]) return;
    let change = {}; change[keys[key]] = keys[key] === "name" ? value : value === "yes";
    update(address, change);
    // A device state event can arrive before (or without) the command reply.
    // Only the requested device becoming disconnected completes this action.
    if (operation === "disconnect" && address.toUpperCase() === target.toUpperCase()
        && key === "Connected" && value === "no") finish();
  }
  function ingest(chunk) {
    buffer += chunk;
    // Keep incomplete ANSI sequences until their final byte arrives.
    buffer = buffer.replace(/\x1b\[[0-?]*[ -\/]*[@-~]/g, "").replace(/\r/g, "");
    let end;
    while ((end = buffer.indexOf("\n")) >= 0) {
      const record = buffer.slice(0, end); buffer = buffer.slice(end + 1); line(record);
      agentPrompt(record);
    }
    agentPrompt(buffer);
    if (buffer.length > 8192) buffer = buffer.slice(-4096);
  }
  function agentPrompt(text) {
    if (!busy || !text.includes("[agent]")) return;
    if (/Enter PIN code:/.test(text)) { promptKind = "pin"; prompt = "Enter PIN code"; }
    else if (/Enter passkey.*:/.test(text)) { promptKind = "passkey"; prompt = "Enter passkey (0–999999)"; }
    else if (/\(yes\/no\):/.test(text)) { promptKind = "confirm"; prompt = text.slice(text.indexOf("[agent]") + 7).trim(); }
    else if (/PIN code:|Passkey:/.test(text)) { promptKind = "display"; prompt = text.slice(text.indexOf("[agent]") + 7).trim(); }
  }
  onViewersChanged: {
    if (viewers > 0) { if (!session.running) start(); else refresh(); }
    else shutdown();
  }
  Timer {
    id: startup; interval: 5000
    onTriggered: if (!root.available && root.viewers > 0) {
      root.shutdown(); root.error = "Bluetooth unavailable. Check bluetoothctl, bluetooth.service and session permissions."; restart.restart();
    }
  }
  Timer { id: scanDeadline; interval: 20000; onTriggered: root.stopScan() }
  Timer { id: deadline; onTriggered: { root.cancel(); root.error = "Bluetooth operation timed out"; } }
  Timer { id: restart; interval: 1500; onTriggered: if (root.viewers > 0) root.start() }
  Timer { interval: 15000; running: root.viewers > 0; repeat: true; onTriggered: root.refresh() }
  Process {
    id: session
    command: ["bluetoothctl"]
    // BlueZ stores interactive history under XDG_CACHE_HOME. /dev/null is not
    // a directory, so no history file can be read or written by this process.
    // qmllint disable incompatible-type
    environment: ({LC_ALL:"C", TERM:"dumb", XDG_CACHE_HOME:"/dev/null"})
    // qmllint enable incompatible-type
    stdinEnabled: true
    onStarted: { root.available = false; root.send("list"); root.send("show"); root.send("devices"); }
    stdout: StdioCollector {
      waitForEnd: false
      onTextChanged: {
        const chunk = text.slice(root.consumed); root.consumed = text.length;
        root.ingest(chunk);
        // Bound retained terminal output; restart only outside operations.
        if (text.length > 131072 && !root.busy) { root.shutdown(); restart.restart(); }
      }
    }
    stderr: SplitParser { onRead: {} }
    onExited: {
      root.available = false; root.powered = false; root.scanning = false;
      root.pending = ""; root.operation = ""; root.prompt = ""; root.promptKind = "";
      deadline.stop(); root.adapters = []; root.devices = []; root.selected = "";
      if (!root.stopping) { root.error = "bluetoothctl stopped. Check Bluetooth service and session permissions."; restart.restart(); }
    }
  }
}
