import QtQuick
import Quickshell
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/common" as Design
import "../../config/quickshell/astral-bar/settings" as Settings

ShellRoot {
  id: root
  property int stage: 0
  property int ticks: 0
  property bool modeChanging: false
  function mode(value) {
    modeChanging = true;
    controller.run(["test-mode", value], () => { Data.NetworkData.refresh(); modeChanging = false; });
  }
  Data.NmCommand { id: controller }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (let child of item.children) { const found = find(child, name); if (found) return found; }
    return null;
  }
  function check(condition, message) { if (!condition) throw new Error(message); }
  QtObject { id: settings; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: settings }
  property bool timedOut: false
  Data.NmCommand { id: bounded; timeoutMs: 50 }
  Component.onCompleted: bounded.run(["test-timeout"], code => { root.check(code === 124, "timeout exit"); root.timedOut = true; })
  Panel.WifiCard { id: card; tokens: theme; width: 350 }
  Loader { id: secondView; active: true; sourceComponent: Panel.WifiCard { tokens: theme; width: 250 } }
  Timer {
    interval: 100; running: true; repeat: true
    onTriggered: {
      try {
        root.check(++root.ticks < 500, "deadline");
        const n = Data.NetworkData;
        if (n.loading || n.busy || (!n.available && root.stage !== 8) || !root.timedOut || root.modeChanging) return;
        if (root.stage === 0) {
          root.check(n.adapters.length === 2, "adapters");
          root.check(n.selected === "wlan0", "selected connected adapter");
          root.check(n.connectedDevice.name === "en0", "Ethernet priority");
          root.check(Data.SystemData.networkState === "ethernet" && Data.SystemData.networkLabel === "ETH", "bar shows wired connection");
          root.check(n.networks.length === 3 && n.networks[0].signal === 77, "grouping");
          root.check(n.profiles.length === 2, "profiles");
          root.check(n.compatible(n.networks[0]).length === 2, "duplicate profile choice");
          root.check(n.viewers === 2, "shared viewers");
          card.choose(n.networks[0]);
          const field = root.find(card, "wifiPassword");
          field.text = "test-secret";
          card.reset();
          root.check(field.text === "" && !card.form, "cancel discards password");
          n.activate("saved-id", "test-secret");
          secondView.active = false;
          root.check(n.busy, "closing view preserves operation");
          n.forget("saved-id"); // Must be ignored while activation holds the write lock.
          root.stage++;
        } else if (root.stage === 1) {
          root.check(n.error.indexOf("10") >= 0, "activation error preserved");
          root.check(n.viewers === 1, "closed view released");
          secondView.active = true;
          n.connectNew("Hidden", "wpa-psk", "test-secret", true);
          root.stage++;
        } else if (root.stage === 2) {
          root.check(n.error.indexOf("10") >= 0, "new profile rollback");
          n.forget("saved-id");
          root.stage++;
        } else if (root.stage === 3) {
          root.check(n.error.indexOf("4") >= 0, "permission error");
          n.selected = "wlan1";
          root.stage++;
        } else if (root.stage === 4) {
          root.check(n.selected === "wlan1", "adapter switch");
          root.mode("off"); root.stage++;
        } else if (root.stage === 5) {
          root.check(n.state === "Radio off", "radio off");
          root.check(Data.SystemData.networkState === "ethernet", "Wi-Fi radio off preserves active Ethernet indicator");
          root.mode("blocked"); root.stage++;
        } else if (root.stage === 6) {
          root.check(n.state === "Hardware blocked", "hardware block");
          root.mode("absent"); root.stage++;
        } else if (root.stage === 7) {
          root.check(n.state === "No Wi-Fi adapter", "absent adapter");
          root.mode("unavailable"); root.stage++;
        } else if (root.stage === 8) {
          root.check(n.state === "Service unavailable", "service unavailable");
          root.check(Data.SystemData.networkState === "unavailable", "bar shows unavailable service");
          root.mode("wifi"); root.stage++;
        } else if (root.stage === 9) {
          root.check(Data.SystemData.networkState === "wifi" && Data.SystemData.networkLabel === "WiFi", "bar shows Wi-Fi connection");
          root.check(Data.SystemData.networkLevel === 0.77, "bar shows Wi-Fi strength");
          root.mode("disconnected"); root.stage++;
        } else if (root.stage === 10) {
          root.check(Data.SystemData.networkState === "disconnected" && Data.SystemData.networkLabel === "Offline", "bar distinguishes disconnected network");
          root.mode("radio-off"); root.stage++;
        } else if (root.stage === 11) {
          root.check(Data.SystemData.networkState === "off" && Data.SystemData.networkLabel === "Off", "bar distinguishes disabled radio");
          root.mode("normal"); root.stage++;
        } else {
          if (root.ticks < 65) return; // Wait for monitor restart and grouped event refresh.
          root.check(n.available && n.adapters.length === 2, "recovery");
          console.log("NETWORK_SERVICE_PASS");
          Qt.quit();
        }
      } catch (error) { console.log("NETWORK_SERVICE_FAIL", error.message); Qt.quit(); }
    }
  }
}
