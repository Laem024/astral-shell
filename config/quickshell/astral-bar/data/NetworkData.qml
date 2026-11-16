pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "NetworkLogic.js" as Logic

Singleton {
  id: root
  property var devices: []
  readonly property var adapters: devices.filter(d => d.type === "wifi")
  property var networks: []
  property var profiles: []
  property string selected: ""
  readonly property var adapter: adapters.find(d => d.name === selected) || null
  readonly property var connectedDevice: devices.find(d => d.type === "ethernet" && d.state === "connected")
    || devices.find(d => d.type === "wifi" && d.state === "connected") || null
  property bool available: false
  property bool radio: false
  property bool hardware: true
  property bool loading: false
  property string pending: ""
  readonly property bool busy: pending !== ""
  property string error: ""
  property int viewers: 0
  property int generation: 0
  property bool again: false
  readonly property string state: loading && !available ? "Loading…" : !available ? "Service unavailable" : !adapters.length ? "No Wi-Fi adapter"
    : !hardware ? "Hardware blocked" : !radio ? "Radio off" : busy ? pending : loading ? "Loading…"
    : adapter ? adapter.state + (adapter.connection ? " · " + adapter.connection : "") : "Disconnected"
  readonly property real strength: {
    const active = networks.find(n => n.active && connectedDevice && n.device === connectedDevice.name);
    return active ? active.signal / 100 : 0;
  }

  function read(args, request, callback) {
    reader.run(args, (code, out) => {
      if (request !== generation) { endRead(); return; }
      callback(code, out);
    });
  }
  function refresh() {
    if (loading) { again = true; return; }
    loading = true;
    again = false;
    const request = ++generation;
    read(["--fields", "DEVICE,TYPE,STATE,CONNECTION,CON-UUID", "device", "status"], request, (code, out) => {
      if (request !== generation) { endRead(); return; }
      available = code === 0;
      if (code !== 0) { devices = []; networks = []; profiles = []; endRead(); return; }
      devices = Logic.rows(out).map(f => ({ name:f[0], type:f[1], state:f[2], connection:f[3] === "--" ? "" : f[3], uuid:f[4] }));
      if (!adapters.some(d => d.name === selected)) selected = (adapters.find(d => d.state === "connected") || adapters[0] || {name:""}).name;
      read(["--fields", "WIFI,WIFI-HW", "general", "status"], request, (status, value) => {
        if (status === 0) { const f = Logic.rows(value)[0] || []; radio = f[0] === "enabled"; hardware = f[1] === "enabled"; }
        read(["--fields", "DEVICE,IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"], request, (status, value) => {
          networks = status === 0 ? Logic.networks(value) : [];
          read(["--fields", "UUID,NAME,TYPE,DEVICE", "connection", "show"], request, (status, value) => {
            const list = status === 0 ? Logic.rows(value).filter(f => f[2] === "802-11-wireless").map(f => ({uuid:f[0], name:f[1], device:f[3], ssid:"", security:"", iface:""})) : [];
            readProfile(list, 0, request);
          });
        });
      });
    });
  }
  function readProfile(list, index, request) {
    if (request !== generation) { endRead(); return; }
    if (index >= list.length) { profiles = list; endRead(); return; }
    read(["--mode", "tabular", "--fields", "802-11-wireless.ssid,802-11-wireless-security.key-mgmt,connection.interface-name", "connection", "show", "uuid", list[index].uuid], request, (code, out) => {
      if (code === 0) {
        // Detailed property queries return one escaped value per line.
        const f = Logic.values(out);
        list[index].ssid = f[0] || "";
        list[index].security = f[1] || "";
        list[index].iface = f[2] === "--" ? "" : f[2] || "";
      }
      readProfile(list, index + 1, request);
    });
  }
  function endRead() { loading = false; if (again) Qt.callLater(refresh); }
  function compatible(network) {
    return profiles.filter(p => p.ssid === network.ssid && (!p.iface || p.iface === selected)
      && Logic.compatible(network.security, p.security));
  }
  function begin(label) {
    if (busy || !available) return false;
    generation++;
    if (loading) again = true;
    pending = label; error = ""; return true;
  }
  function done(code) {
    if (code !== 0) error = code === 124 ? "Operation timed out. State refreshed; try again."
      : "NetworkManager operation failed (" + code + "). Check the password, adapter and session PolicyKit authorization.";
    pending = "";
    refresh();
  }
  function action(label, args) { if (begin(label)) writer.run(args, code => done(code)); }
  function scan() { if (selected && radio) action("Scanning…", ["device", "wifi", "rescan", "ifname", selected]); }
  function setRadio(enabled) { action("Changing radio…", ["radio", "wifi", enabled ? "on" : "off"]); }
  function disconnect() { if (selected) action("Disconnecting…", ["device", "disconnect", selected]); }
  function forget(uuid) { if (profiles.some(p => p.uuid === uuid)) action("Forgetting…", ["connection", "delete", "uuid", uuid]); }
  function activate(uuid, password = "", hidden = false) {
    if (!selected || !profiles.some(p => p.uuid === uuid) || !validPassword(password) || !begin("Connecting…")) return;
    const iface = selected;
    if (hidden) {
      writer.run(["connection", "modify", "uuid", uuid, "802-11-wireless.hidden", "yes"], code => {
        if (code !== 0) { password = ""; done(code); return; }
        up(uuid, iface, password, result => done(result));
        password = "";
      });
    } else up(uuid, iface, password, code => done(code));
  }
  function validPassword(password) {
    if (/[\r\n\0]/.test(password)) { error = "Password cannot contain line breaks or NUL."; return false; }
    return true;
  }
  function up(uuid, iface, password, callback) {
    let args = ["connection", "up", "uuid", uuid, "ifname", iface];
    if (password) args = args.concat(["passwd-file", "/dev/stdin"]);
    writer.run(args, callback, password ? "802-11-wireless-security.psk:" + password + "\n" : "");
  }
  function connectNew(ssid, security, password, hidden) {
    if (!ssid || !selected || !validPassword(password) || !["open", "wpa-psk", "sae"].includes(security) || !begin("Connecting…")) return;
    const iface = selected;
    // Assign the UUID before creation so cleanup never depends on a display name.
    const uuid = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => { const n = Math.floor(Math.random()*16); return (c === "x" ? n : (n & 3)|8).toString(16); });
    let args = ["connection", "add", "type", "wifi", "ifname", iface, "con-name", ssid, "ssid", ssid,
      "connection.uuid", uuid, "connection.autoconnect", "no", "802-11-wireless.hidden", hidden ? "yes" : "no", "ipv4.method", "auto", "ipv6.method", "auto"];
    if (security !== "open") args = args.concat(["wifi-sec.key-mgmt", security, "wifi-sec.psk-flags", "0"]);
    writer.run(args, code => {
      if (code !== 0) { password = ""; cleanupNew(uuid, code); return; }
      up(uuid, iface, password, status => {
        if (status !== 0) { cleanupNew(uuid, status); return; }
        writer.run(["connection", "modify", "uuid", uuid, "connection.autoconnect", "yes"], result => done(result));
      });
      password = "";
    });
  }
  function cleanupNew(uuid, failure) {
    writer.run(["connection", "delete", "uuid", uuid], code => {
      done(failure);
      if (code !== 0) error += " Could not remove the new profile " + uuid + "; review saved profiles.";
    });
  }
  onSelectedChanged: { generation++; refresh(); }
  Component.onCompleted: refresh()
  NmCommand { id: reader }
  NmCommand { id: writer }
  Timer { interval: root.viewers > 0 ? 15000 : 60000; running: true; repeat: true; onTriggered: root.refresh() }
  Timer { id: debounce; interval: 400; onTriggered: root.refresh() }
  Timer { id: restartMonitor; interval: 5000; onTriggered: monitor.running = true }
  Process {
    id: monitor
    command: ["env", "LC_ALL=C", "nmcli", "--colors", "no", "monitor"]
    running: true
    stdout: SplitParser { onRead: debounce.restart() }
    stderr: SplitParser { onRead: {} }
    onRunningChanged: if (!running) restartMonitor.restart()
  }
}
