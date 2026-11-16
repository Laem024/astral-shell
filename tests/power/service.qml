import QtQuick
import Quickshell
import Quickshell.Io
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/common" as Common

ShellRoot {
  id: root
  property int phase: 0
  property int ticks: 0
  property bool acceptProfile: false
  property int writes: 0
  property double began: Date.now()
  function check(ok, label) { if (!ok) { console.error("POWER_FAIL " + label); Qt.exit(1); } }
  FileView { id: profile; path: Quickshell.env("ASTRAL_FIXTURE") + "/native-profile"; atomicWrites: true }
  Data.PowerService {
    id: power
    performanceAvailable: false
    setNativeProfile: function(name) { root.writes++; if (root.acceptProfile) profile.setText(name); }
  }
  Timer {
    interval: 100; repeat: true; running: true
    onTriggered: {
      if (++root.ticks > 180) root.check(false, "timeout at phase " + root.phase);
      if (root.phase === 0) {
        if (!power.profilesAvailable || !power.chargeAvailable) return;
        power.caffeineStatusError = "Logind has not confirmed the inhibitor.";
        power.caffeinePending = true;
        root.check(power.caffeineError === "", "caffeine startup waits for confirmation without an error");
        power.caffeinePending = false;
        root.check(power.caffeineError !== "", "unconfirmed caffeine reports an error after waiting");
        power.caffeineVerificationFailed = true;
        power.caffeineOperationError = "Confirmation timed out.";
        power.caffeineStatusError = "";
        power.confirmCaffeine();
        root.check(power.caffeineError === "", "late caffeine confirmation clears the timeout");
        power.caffeineOperationError = "Could not start systemctl.";
        power.confirmCaffeine();
        root.check(power.caffeineError !== "", "confirmation preserves unrelated operation failures");
        power.caffeineOperationError = "";
        root.check(power.profile === "balanced", "daemon profile read");
        power.chooseProfile("performance");
        root.check(!power.profilePending && root.writes === 0, "unsupported profile rejected");
        power.chooseProfile("power-saver"); root.phase++;
      } else if (root.phase === 1) {
        if (power.profilePending) return;
        root.check(power.profile === "balanced" && power.profileError !== "", "optimistic profile is not shown as applied");
        root.acceptProfile = true; power.chooseProfile("power-saver"); root.phase++;
      } else if (root.phase === 2) {
        if (power.profilePending) return;
        root.check(power.profile === "power-saver" && power.profileError === "", "profile confirmed by independent read");
        root.check(!Data.SessionData.available("lock") && !Data.SessionData.available("suspend"), "missing providers disable lock and suspend");
        Data.SessionData.ask("lock"); root.check(!Data.SessionData.pending, "missing provider sends no action");
        power.chargeApply("0"); root.check(!power.chargePending && power.chargeError !== "", "invalid threshold rejected");
        power.chargeApply("65"); root.phase++;
      } else if (root.phase === 3) {
        if (power.chargePending) return;
        root.check(power.chargeError.includes("cancelled") && power.chargeCurrent === 100, "authentication cancellation preserves threshold");
        Data.SessionData.ask("reboot"); root.check(Data.SessionData.confirmation === "reboot" && !Data.SessionData.pending, "confirmation required");
        Data.SessionData.cancel(); root.check(Data.SessionData.confirmation === "", "confirmation cancellation");
        Data.SessionData.ask("reboot"); Data.SessionData.confirm(); root.phase++;
      } else if (root.phase === 4) {
        if (Data.SessionData.pending) return;
        root.check(Data.SessionData.error.includes("simulated"), "provider failure is reported");
        console.log("POWER_PASS"); Qt.quit();
      }
    }
  }
}
