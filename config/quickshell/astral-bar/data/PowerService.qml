import QtQuick
import Quickshell
import Quickshell.Io
import "../../common" as Common

// Kept separate so tests can substitute only the native setter in a private copy.
QtObject {
  id: root
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
  readonly property string caffeineError: caffeineOperationError || (caffeinePending ? "" : caffeineStatusError)
  property bool caffeineVerificationFailed: false
  property bool caffeinePending: false
  property bool caffeineExpected: false
  readonly property string chargeHelper: "/usr/local/libexec/astral-charge-limit"
  property Common.Command chargeGate: Common.Command {}
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
  function caffeineToggle() {
    if (caffeinePending) return;
    caffeineOperationError = ""; caffeineVerificationFailed = false; caffeinePending = true;
    caffeineGate.acquire();
  }
  property Common.StartupLock caffeineGate: Common.StartupLock {
    key: "session-action"
    onAcquired: root.saveCaffeine()
    onFailed: message => { root.caffeinePending = false; root.caffeineOperationError = message; }
  }
  function saveCaffeine() {
    caffeineDirectory.run(["mkdir", "-p", "-m", "700", "--", Common.Paths.state], code => {
      if (code !== 0) { caffeineGate.release(); caffeinePending = false; caffeineOperationError = "Cannot save caffeine preference."; return; }
      caffeineFile.reload();
      caffeineFile.waitForJob();
      caffeineSaved = caffeineFile.text().trim() === "on";
      caffeineFile.setText(caffeineSaved ? "off\n" : "on\n");
    });
  }
  property Common.Command caffeineDirectory: Common.Command {}
  property FileView caffeineFile: FileView {
    path: Common.Paths.state + "/caffeine"
    blockLoading: true
    printErrors: false
    atomicWrites: true
    onSaved: {
      root.caffeineGate.release();
      root.caffeineSaved = text().trim() === "on";
      root.caffeineExpected = root.caffeineSaved;
      caffeineChange.command = ["systemctl", "--user", root.caffeineSaved ? "start" : "stop", "astral-caffeine.service"];
      caffeineChange.running = true;
    }
    onLoaded: root.caffeineSaved = text().trim() === "on"
    onSaveFailed: { root.caffeineGate.release(); root.caffeinePending = false; root.caffeineOperationError = "Could not save caffeine preference."; }
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
    verifyChargeHelper(ok => {
      if (!ok) { chargePending = false; chargeOperationError = "Install the protected root-owned charge helper."; return; }
      chargeChange.command = ["pkexec", chargeHelper].concat(args);
      chargeChange.running = true;
    });
  }
  function verifyChargeHelper(done) {
    chargeGate.run(["stat", "-c", "%u:%a:%F", "--", chargeHelper], (code, output) => {
      const fields = output.trim().split(":");
      const mode = parseInt(fields[1], 8);
      done(code === 0 && fields[0] === "0" && fields[2] === "regular file" && Number.isFinite(mode) && (mode & 18) === 0);
    });
  }
  property Timer caffeineVerification: Timer {
    interval: 8000
    onTriggered: {
      if (root.caffeinePending) {
        root.caffeineVerificationFailed = true;
        root.caffeineOperationError = "Preference saved, but logind did not confirm the requested inhibitor state.";
      }
      root.caffeinePending = false;
    }
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
    command: ["busctl", "--system", "--timeout=2", "get-property", "org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles", "org.freedesktop.UPower.PowerProfiles", "ActiveProfile"]
    stdout: StdioCollector { id: profileOutput }
    stderr: StdioCollector { id: profileFailure }
    onExited: (code, status) => {
      const match = /^s "(power-saver|balanced|performance)"$/.exec(profileOutput.text.trim());
      const value = match ? match[1] : "";
      root.profilesAvailable = code === 0 && status === 0 && ["power-saver", "balanced", "performance"].includes(value);
      root.profile = root.profilesAvailable ? value : "";
      root.profileStatusError = root.profilesAvailable ? "" : profileFailure.text.trim() || "Power profiles unavailable.";
      if (root.profilePending && root.profile === root.requestedProfile) { root.requestedProfile = ""; root.verify.stop(); }
    }
  }
  property Common.Command caffeineRead: Common.Command {}
  property Common.Command caffeineUnit: Common.Command {}
  function confirmCaffeine() {
    caffeinePending = false;
    caffeineVerification.stop();
    if (caffeineVerificationFailed) {
      caffeineVerificationFailed = false;
      caffeineOperationError = "";
    }
  }
  function refreshCaffeine() {
    caffeineFile.reload();
    caffeineSaved = caffeineFile.text().trim() === "on";
    if (!caffeineRead.running) caffeineRead.run(["qs", "ipc", "-p", Common.Paths.home + "/.local/lib/astral-shell/common/Caffeine.qml", "call", "caffeine", "status"], (code, output) => {
      try {
        const data = JSON.parse(output); caffeineActive = code === 0 && data.active;
        caffeineStatusError = data.error || "";
        if (code === 0 && !caffeineStatusError && !caffeineChange.running
            && (!caffeinePending || caffeineVerification.running)
            && caffeineActive === caffeineExpected) confirmCaffeine();
      } catch (_) {
        caffeineActive = false; caffeineStatusError = caffeineSaved ? "Caffeine service has not confirmed inhibitors." : "";
        if (!caffeineSaved && !caffeineExpected && !caffeineChange.running
            && (!caffeinePending || caffeineVerification.running)) confirmCaffeine();
      }
    });
    if (!caffeineUnit.running) caffeineUnit.run(["systemctl", "--user", "show", "astral-caffeine.service", "--property=LoadState", "--value"], (code, output) => caffeineAvailable = code === 0 && output.trim() === "loaded");
  }
  property Process caffeineChange: Process {
    onRunningChanged: if (!running && root.caffeinePending && !root.caffeineVerification.running) Qt.callLater(() => {
      if (!caffeineChange.running && root.caffeinePending && !root.caffeineVerification.running) { root.caffeinePending = false; root.caffeineOperationError = "Could not start systemctl."; }
    })
    stderr: StdioCollector { id: caffeineFailure }
    onExited: (code, status) => {
      if (code !== 0 || status !== 0) { root.caffeinePending = false; root.caffeineOperationError = caffeineFailure.text.trim() || "Could not change caffeine."; }
      else root.caffeineVerification.restart();
      root.refreshCaffeine();
    }
  }
  property Process chargeRead: Process {
    command: [root.chargeHelper, "status"]
    stdout: StdioCollector { id: chargeOutput }
    stderr: StdioCollector { id: chargeFailure }
    onExited: (code, status) => {
      const lines = chargeOutput.text.trim().split("\n");
      root.chargeAvailable = code === 0 && status === 0 && lines.length >= 2 && /^[A-Za-z0-9_-]+$/.test(lines[0])
        && /^[1-9][0-9]?$|^100$/.test(lines[1]);
      root.chargeDevice = root.chargeAvailable ? lines[0] : "";
      root.chargeCurrent = root.chargeAvailable ? Number(lines[1]) : -1;
      root.chargeSaved = root.chargeAvailable && lines[2] === lines[0] && lines[3] ? Number(lines[3]) : -1;
      root.chargeStatusError = root.chargeAvailable ? "" : chargeFailure.text.trim() || "Charge limit unavailable.";
    }
  }
  property Process chargeChange: Process {
    onRunningChanged: if (!running && root.chargePending) Qt.callLater(() => {
      if (!chargeChange.running && root.chargePending) { root.chargePending = false; root.chargeOperationError = "Could not start authentication."; }
    })
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
      root.refreshCaffeine();
      if (!root.chargePending && !root.chargeRead.running && !root.chargeGate.running) root.verifyChargeHelper(ok => {
        if (ok) root.chargeRead.running = true;
        else { root.chargeAvailable = false; root.chargeStatusError = "Install the protected root-owned charge helper."; }
      });
    }
  }
}
