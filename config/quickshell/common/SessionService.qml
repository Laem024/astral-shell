import QtQuick
import Quickshell
import Quickshell.Io
import "." as Common

Scope {
  id: root
  readonly property bool ready: Common.Privacy.ready
  readonly property bool blocked: deferred !== "" || Common.Privacy.blocked
  property string confirmation: ""
  property string error: ""
  property bool pending: false
  readonly property var providers: Common.SettingsData.value.providers
  property string deferred: ""
  property double lockDeadline: 0
  signal completed(string action)
  function available(action) { return !!providers[action] && providers[action].length > 0 && (action !== "suspend" || providers.lock.length > 0); }
  function lock(): void { ask("lock"); }
  function ask(action): void {
    if (pending || !available(action) || blocked) return;
    if (["lock", "suspend"].includes(action)) perform(action);
    else if (["logout", "reboot", "poweroff"].includes(action)) { error = ""; confirmation = action; }
  }
  function cancel(): void { confirmation = ""; }
  function confirm(): void { const action = confirmation; confirmation = ""; if (["logout", "reboot", "poweroff"].includes(action)) perform(action); }
  function perform(action): void {
    if (pending || !available(action) || blocked) return;
    error = ""; pending = true;
    if (action === "lock" || action === "suspend") {
      deferred = action; lockDeadline = Date.now() + 15000; Common.Privacy.refresh();
      // The locker must survive a bar reload. Logind confirms its success.
      Quickshell.execDetached(providers.lock);
    } else request.run(providers[action], (code, output, failure) => {
      pending = false; if (code !== 0) error = failure || "Session action failed.";
      else completed(action);
    });
  }
  function abort(message) { deferred = ""; pending = false; error = message; }
  Common.Command { id: request }
  function refreshPrivacy() {
    if (!deferred || !Common.Privacy.ready) return;
    if (Common.Privacy.hint === "yes" && !request.running) {
      const action = deferred; deferred = "";
      if (action === "lock") { pending = false; completed(action); }
      else request.run(providers.suspend, (code, out, failure) => {
        pending = false; if (code !== 0) error = failure || "Suspend failed."; else completed(action);
      });
    } else if (Date.now() > lockDeadline) abort("Lock was not confirmed by logind; session action cancelled.");
  }
  Timer { interval: 500; repeat: true; running: true; onTriggered: root.refreshPrivacy() }
}
