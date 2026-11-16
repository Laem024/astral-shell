import QtQuick
import Quickshell
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/common" as Design
import "../../config/quickshell/astral-bar/settings" as Settings

Scope {
  id: root
  property int stage: 0
  property int ticks: 0
  property bool modeChanging: false
  function check(condition, message) { if (!condition) throw new Error(message); }
  function mode(value) {
    modeChanging = true;
    controller.run(["test-mode", value], () => { modeChanging = false; });
  }
  QtObject { id: settings; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: settings }
  Data.NmCommand { id: controller }
  Panel.VpnCard { id: card; tokens: theme; width: 320 }
  Timer {
    interval: 100; running: true; repeat: true
    onTriggered: {
      const v = Data.VpnData;
      root.ticks++;
      if (root.ticks > 200) { console.log("VPN_SERVICE_FAIL", root.stage, v.error, v.pending); Qt.quit(); return; }
      if (v.loading || v.busy || root.modeChanging) return;
      try {
        if (root.stage === 0) {
          if (!v.available) return;
          root.check(v.profiles.length === 2, "profile filtering");
          root.check(v.profiles[0].name === "wg0" && !v.profiles[0].active, "WireGuard listed");
          root.check(v.profiles[1].name === "Office" && v.profiles[1].type === "vpn", "OpenVPN listed");
          root.check(!v.profiles.some(p => ["Ignored", "Home", "Cable"].includes(p.name)), "unsupported profiles hidden");
          root.check(v.active.length === 0 && v.state === "2 profiles", "initial state");
          root.check(v.viewers === 1, "shared viewers");
          root.check(card.section === "profiles", "initial view");
          root.check(card.kindOf("office.ovpn") === "openvpn" && card.kindOf("wg.conf") === "wireguard", "file type detection");
          v.toggle("wg-id");
          root.check(v.busy, "activation starts");
          root.stage = 1;
        } else if (root.stage === 1) {
          root.check(v.profiles.find(p => p.uuid === "wg-id").active, "WireGuard connected");
          root.check(v.state === "Connected · wg0", "connected state");
          v.toggle("wg-id");
          root.check(v.busy, "deactivation starts");
          root.stage = 2;
        } else if (root.stage === 2) {
          root.check(!v.profiles.find(p => p.uuid === "wg-id").active, "WireGuard disconnected");
          v.importFile("/tmp/fixture.conf", "wireguard");
          root.check(v.busy, "import starts");
          root.stage = 3;
        } else if (root.stage === 3) {
          root.check(v.profiles.some(p => p.uuid === "imported-id"), "imported WireGuard profile");
          root.check(v.profiles.length === 3, "profile added after import");
          v.importFile("/tmp/office.ovpn", "openvpn");
          root.stage = 4;
        } else if (root.stage === 4) {
          root.check(v.profiles.some(p => p.uuid === "office2-id"), "imported OpenVPN profile");
          v.importFile("/tmp/x.conf", "pptp");
          root.check(v.error === "Unsupported VPN type.", "unsupported type rejected");
          v.importFile("relative.conf", "wireguard");
          root.check(v.error === "Choose a readable .conf or .ovpn file.", "relative path rejected");
          root.check(!v.busy, "invalid import did not run");
          card.openImport();
          root.check(card.section === "import", "import view");
          card.chooseFile("office.ovpn", "file:///tmp/office.ovpn");
          root.check(card.importType === "openvpn" && card.importPath === "/tmp/office.ovpn", "OpenVPN selection");
          card.chooseFile("fixture.conf", "file:///tmp/fixture.conf");
          root.check(card.importType === "wireguard" && card.importPath === "/tmp/fixture.conf", "WireGuard selection");
          card.clearImport();
          card.closeImport();
          root.check(card.section === "profiles" && card.importName === "", "import view closes");
          root.mode("import-fail");
          root.stage = 5;
        } else if (root.stage === 5) {
          v.importFile("/tmp/fail.conf", "wireguard");
          root.stage = 6;
        } else if (root.stage === 6) {
          root.check(v.error.indexOf("10") >= 0, "import failure surfaced");
          v.remove("vpn-id");
          root.check(v.busy, "removal starts");
          root.stage = 7;
        } else if (root.stage === 7) {
          root.check(!v.profiles.some(p => p.uuid === "vpn-id"), "profile removed");
          root.check(v.error === "", "successful removal clears error");
          console.log("VPN_SERVICE_PASS");
          Qt.quit();
        }
      } catch (error) { console.log("VPN_SERVICE_FAIL", error.message); Qt.quit(); }
    }
  }
}
