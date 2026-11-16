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
  QtObject { id: settings; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: settings }
  Panel.BluetoothCard { tokens: theme; width: 300 }
  Panel.BluetoothCard { tokens: theme; width: 240 }
  Timer {
    interval: 100; running: true; repeat: true
    onTriggered: {
      const b = Data.BluetoothData;
      root.ticks++;
      if (root.ticks > 100) { console.log("BLUETOOTH_FAIL", root.stage, b.error, b.pending); Qt.quit(); return; }
      if (root.stage === 0 && b.devices.length && b.powered) {
        if (b.viewers !== 2) throw new Error("shared views");
        b.scan(); if (!b.scanning) return;
        b.stopScan(); b.connectDevice(b.devices[0].address); root.stage++;
      } else if (root.stage === 1 && b.promptKind === "pin") {
        b.answer("123456"); root.stage++;
      } else if (root.stage === 2 && !b.busy && b.devices[0].connected) {
        b.disconnectDevice(b.devices[0].address);
        b.line("[CHG] Device 00:00:00:00:00:01 Connected: no");
        if (!b.busy) throw new Error("unrelated disconnect completed action");
        b.line("[CHG] Device " + b.target + " Connected: yes");
        if (!b.busy) throw new Error("connected event completed disconnect");
        root.stage++;
      } else if (root.stage === 3 && !b.busy && !b.devices[0].connected) {
        if (b.error !== "") throw new Error("disconnect failed: " + b.error);
        b.connectDevice(b.devices[0].address); root.stage++;
      } else if (root.stage === 4 && !b.busy && b.devices[0].connected) {
        b.forget(b.devices[0].address); root.stage++;
      } else if (root.stage === 5 && !b.busy) {
        // Exercise event parsing without touching hardware.
        b.ingest("\x1b[0;32m[CHG] Device AA:BB:CC:DD:EE:FF Alias: Auriculares café\x1b[0m\n");
        if (b.devices.find(d => d.address === "AA:BB:CC:DD:EE:FF").name !== "Auriculares café") throw new Error("Unicode / ANSI");
        b.line("Controller 00:11:22:33:44:55 Other adapter");
        b.line("\tPowered: no");
        if (!b.powered || b.adapters.length !== 2) throw new Error("adapter isolation");
        b.pending = "Pairing…"; b.operation = "pair";
        b.ingest("[agent] Confirm passkey 000123 (yes/");
        b.ingest("no):");
        if (b.promptKind !== "confirm") throw new Error("fragmented confirmation");
        b.answer("yes");
        b.agentPrompt("[agent] Enter passkey (number in 0-999999):");
        b.answer("invalid");
        if (b.promptKind !== "passkey") throw new Error("invalid passkey accepted");
        b.cancel();
        if (b.busy || b.promptKind) throw new Error("cancel did not clear prompt");
        root.stage++;
      } else if (root.stage === 6 && b.available && b.selected) {
        b.operationTimeout = 50;
        b.begin("test", "", "Timeout test"); root.stage++;
      } else if (root.stage === 7 && !b.busy && b.error.includes("timed out")) {
        root.stage++;
      } else if (root.stage === 8 && b.available && b.devices.length) {
        console.log("BLUETOOTH_PASS"); Qt.quit();
      }
    }
  }
}
