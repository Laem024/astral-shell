import QtQuick
import Quickshell
import Quickshell.Io

// Kept separate so tests can substitute only the native setter in a private copy.
QtObject {
  id: root
  property string helperDirectory: decodeURIComponent(Qt.resolvedUrl("../power/").toString().replace(/^file:\/\//, ""))
  property var setNativeProfile: function(name) {}
  property bool performanceAvailable: false
  property bool profilesAvailable: false
  property string profile: ""
  property string requestedProfile: ""
  property string profileOperationError: ""
  property string profileStatusError: ""
  readonly property string profileError: profileOperationError || profileStatusError
  readonly property bool profilePending: requestedProfile !== ""
  property bool caffeineSaved: false
  property bool caffeineActive: false
  property bool caffeineAvailable: true
  property string caffeineOperationError: ""
  property string caffeineStatusError: ""
  readonly property string caffeineError: caffeineOperationError || caffeineStatusError
  property bool caffeinePending: false
  property bool chargeAvailable: false
  property string chargeDevice: ""
  property int chargeCurrent: -1
  property int chargeSaved: -1
  readonly property bool chargeActive: chargeAvailable && chargeSaved > 0 && chargeSaved === chargeCurrent
  property string chargeOperationError: ""
  property string chargeStatusError: ""
  readonly property string chargeError: chargeOperationError || chargeStatusError
  property bool chargePending: false

  function chooseProfile(name: string): void {
    if (!profilesAvailable || profilePending || !["power-saver", "balanced", "performance"].includes(name)
        || (name === "performance" && !performanceAvailable)) return;
    profileOperationError = "";
    requestedProfile = name;
    setNativeProfile(name);
    verify.restart();
  }
  function refreshProfile(): void { if (!profileRead.running) profileRead.running = true; }
  function caffeineToggle(): void {
    if (caffeinePending || caffeineRead.running) return;
    caffeineOperationError = "";
    caffeinePending = true;
    caffeineChange.command = ["bash", helperDirectory + "caffeine.sh", caffeineSaved ? "off" : "on"];
    caffeineChange.running = true;
  }
  function chargeApply(value: string): void {
    if (chargePending || chargeRead.running || !chargeAvailable) return;
    if (!/^(?:[1-9][0-9]?|100)$/.test(value)) { chargeOperationError = "Enter a whole number between 1 and 100."; return; }
    changeCharge(["apply", chargeDevice, value]);
  }
  function chargeDisable(): void {
    if (!chargePending && !chargeRead.running && chargeAvailable) changeCharge(["disable", chargeDevice]);
  }
  function changeCharge(args): void {
    chargeOperationError = "";
    chargePending = true;
    chargeChange.command = ["bash", helperDirectory + "charge.sh"].concat(args);
    chargeChange.running = true;
  }
  property Timer verify: Timer {
    interval: 2500
    onTriggered: {
      root.refreshProfile();
      if (root.profilePending) {
        root.profileOperationError = "The service did not confirm the requested profile.";
        root.requestedProfile = "";
      }
    }
  }
  property Process profileRead: Process {
    command: ["bash", root.helperDirectory + "profile-status.sh"]
    stdout: StdioCollector { id: profileOutput }
    stderr: StdioCollector { id: profileFailure }
    onExited: (code, status) => {
      const value = profileOutput.text.trim();
      root.profilesAvailable = code === 0 && status === 0 && ["power-saver", "balanced", "performance"].includes(value);
      root.profile = root.profilesAvailable ? value : "";
      root.profileStatusError = root.profilesAvailable ? "" : profileFailure.text.trim() || "Power profiles unavailable.";
      if (root.profilePending && root.profile === root.requestedProfile) { root.requestedProfile = ""; root.verify.stop(); }
    }
  }
  property Process caffeineRead: Process {
    command: ["bash", root.helperDirectory + "caffeine.sh", "status"]
    stdout: StdioCollector { id: caffeineOutput }
    onExited: (code, status) => {
      const lines = caffeineOutput.text.trim().split("\n");
      root.caffeineAvailable = code === 0 && status === 0 && lines[2] === "loaded";
      root.caffeineSaved = lines[0] === "on";
      root.caffeineActive = root.caffeineAvailable && lines[1] === "active";
      root.caffeineStatusError = root.caffeineAvailable ? "" : "Service unavailable: install astral-caffeine.service.";
    }
  }
  property Process caffeineChange: Process {
    stderr: StdioCollector { id: caffeineFailure }
    onExited: (code, status) => {
      root.caffeinePending = false;
      if (code !== 0 || status !== 0) root.caffeineOperationError = caffeineFailure.text.trim() || "Could not change caffeine.";
      root.caffeineRead.running = true;
    }
  }
  property Process chargeRead: Process {
    command: ["bash", root.helperDirectory + "charge.sh", "status"]
    stdout: StdioCollector { id: chargeOutput }
    stderr: StdioCollector { id: chargeFailure }
    onExited: (code, status) => {
      const lines = chargeOutput.text.trim().split("\n");
      root.chargeAvailable = code === 0 && status === 0 && lines.length >= 2;
      root.chargeDevice = root.chargeAvailable ? lines[0] : "";
      root.chargeCurrent = root.chargeAvailable ? Number(lines[1]) : -1;
      root.chargeSaved = root.chargeAvailable && lines[2] === lines[0] && lines[3] ? Number(lines[3]) : -1;
      root.chargeStatusError = root.chargeAvailable ? "" : chargeFailure.text.trim() || "Charge limit unavailable.";
    }
  }
  property Process chargeChange: Process {
    stderr: StdioCollector { id: chargeChangeFailure }
    onExited: (code, status) => {
      root.chargePending = false;
      if (code !== 0 || status !== 0) root.chargeOperationError = chargeChangeFailure.text.trim() || "Charge limit not applied (authentication cancelled or driver failure).";
      root.chargeRead.running = true;
    }
  }
  property Timer poll: Timer {
    interval: 2000; repeat: true; running: true; triggeredOnStart: true
    onTriggered: {
      root.refreshProfile();
      if (!root.caffeinePending && !root.caffeineRead.running) root.caffeineRead.running = true;
      if (!root.chargePending && !root.chargeRead.running) root.chargeRead.running = true;
    }
  }
}
