pragma Singleton
import QtQuick
import Quickshell
import "NetworkLogic.js" as Logic

// NetworkManager owns WireGuard and OpenVPN profiles; this service only reads
// their metadata and forwards explicit user actions. Secrets never enter QML.
Singleton {
  id: root
  property var profiles: []
  readonly property var active: profiles.filter(profile => profile.active)
  property bool available: false
  property bool loading: false
  property string pending: ""
  readonly property bool busy: pending !== ""
  property string error: ""
  property int viewers: 0
  property int generation: 0
  property bool again: false
  readonly property string state: !available ? (loading ? "Loading…" : "Service unavailable")
    : busy ? pending
    : !profiles.length ? (loading ? "Loading…" : "No VPN profiles")
    : active.length ? "Connected · " + active.map(profile => profile.name).join(", ")
    : profiles.length + (profiles.length === 1 ? " profile" : " profiles")
  signal imported()

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
    read(["--fields", "NAME,TYPE,UUID,ACTIVE", "connection", "show"], request, (code, out) => {
      if (request !== generation) { endRead(); return; }
      available = code === 0;
      if (code !== 0) { profiles = []; endRead(); return; }
      // "vpn" covers plugin profiles (OpenVPN here) and "wireguard" is native.
      const list = Logic.rows(out)
        .filter(f => f[1] === "wireguard" || f[1] === "vpn")
        .map(f => ({ name: f[0], type: f[1] === "wireguard" ? "wireguard" : "vpn", service: "", uuid: f[2], active: f[3] === "yes" }));
      readServiceTypes(list, 0, request);
    });
  }
  function readServiceTypes(list, index, request) {
    if (request !== generation) { endRead(); return; }
    if (index >= list.length) {
      // Only OpenVPN is offered; other VPN plugins remain untouched.
      profiles = list.filter(profile => profile.type !== "vpn" || profile.service === "org.freedesktop.NetworkManager.openvpn");
      endRead();
      return;
    }
    if (list[index].type !== "vpn") { readServiceTypes(list, index + 1, request); return; }
    read(["--mode", "tabular", "--fields", "vpn.service-type", "connection", "show", "uuid", list[index].uuid], request, (code, out) => {
      if (code === 0) list[index].service = Logic.values(out)[0] || "";
      readServiceTypes(list, index + 1, request);
    });
  }
  function endRead() { loading = false; if (again) Qt.callLater(refresh); }
  function begin(label) {
    if (busy || !available) return false;
    generation++;
    if (loading) again = true;
    pending = label; error = ""; return true;
  }
  function done(code, message) {
    if (code !== 0) error = code === 124 ? "Operation timed out. State refreshed; try again."
      : message + " (" + code + "). Check the profile and NetworkManager permissions.";
    pending = "";
    refresh();
  }
  function setActive(uuid, enabled) {
    const profile = profiles.find(item => item.uuid === uuid);
    if (!profile || profile.active === enabled) return;
    if (!begin(enabled ? "Connecting…" : "Disconnecting…")) return;
    writer.run(["connection", enabled ? "up" : "down", "uuid", uuid],
      code => done(code, enabled ? "NetworkManager could not activate this VPN" : "NetworkManager could not deactivate this VPN"));
  }
  function toggle(uuid) {
    const profile = profiles.find(item => item.uuid === uuid);
    if (profile) setActive(uuid, !profile.active);
  }
  function validPath(path) {
    return typeof path === "string" && path.startsWith("/") && !/[\u0000\r\n]/.test(path);
  }
  function importFile(path, kind) {
    if (!["wireguard", "openvpn"].includes(kind)) { error = "Unsupported VPN type."; return; }
    if (!validPath(path)) { error = "Choose a readable .conf or .ovpn file."; return; }
    if (!begin("Importing profile…")) return;
    writer.run(["connection", "import", "type", kind, "file", path], code => {
      if (code === 0) imported();
      done(code, "NetworkManager could not import this profile. Check the file format and the OpenVPN plugin");
    });
  }
  function remove(uuid) {
    if (!profiles.some(profile => profile.uuid === uuid)) return;
    if (!begin("Removing profile…")) return;
    writer.run(["connection", "delete", "uuid", uuid], code => done(code, "NetworkManager could not remove this profile"));
  }
  Component.onCompleted: refresh()
  NmCommand { id: reader }
  NmCommand { id: writer }
  Timer { interval: root.viewers > 0 ? 15000 : 60000; running: true; repeat: true; onTriggered: root.refresh() }
}
