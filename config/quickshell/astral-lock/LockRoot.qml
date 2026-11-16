pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../common" as Common
import "."

ShellRoot {
  id: root
  property string message: ""
  property bool authenticationError: false
  property bool starting: false
  property bool submitted: false
  property int waitingSeconds: 0
  property bool authenticated: false
  property bool privacyPrepared: false
  property real exitProgress: 0
  readonly property bool busy: authenticated || starting || submitted || (pam.active && !pam.responseRequired)
  signal clearSecrets()
  function startAuthentication(keepError: bool): void {
    if (!sessionLock.secure || pam.active || starting || submitted || authenticated) return;
    clearSecrets();
    starting = true;
    if (!keepError) { authenticationError = false; message = "Preparing access…"; }
    if (!pam.start()) {
      starting = false;
      authenticationError = true;
      message = "Could not start authentication. Press Retry.";
    }
  }
  function sendResponse(response: string): void {
    try {
      if (!sessionLock.secure || !pam.active || !pam.responseRequired || busy || !response.length) return;
      authenticationError = false;
      message = "Verifying password…";
      // Take the response as a transient call argument before clearing views
      // through the pending-state bindings. Never retain it in a property.
      submitted = true;
      pam.respond(response);
    } finally {
      response = "";
      clearSecrets();
    }
  }
  Timer {
    interval: 1000; repeat: true; running: root.submitted
    onRunningChanged: root.waitingSeconds = 0
    onTriggered: root.waitingSeconds++
  }
  // Reopen the password prompt only after PAM has finished a submitted attempt.
  // Never retry service errors or account lockouts in a loop.
  Timer { id: retryPrompt; interval: 0; onTriggered: root.startAuthentication(true) }
  NumberAnimation {
    id: unlockAnimation
    target: root; property: "exitProgress"
    from: 0; to: 1
    duration: Common.SettingsData.value.animations ? 260 : 0
    easing.type: Easing.InCubic
    onFinished: {
      // The compositor remains locked throughout the visual exit. An animation
      // stopped by an error or reload must never release it.
      if (root.authenticated && sessionLock.secure) {
        sessionLock.locked = false;
        hint.setLocked(false, () => Qt.quit());
      } else {
        root.authenticated = false;
        root.exitProgress = 0;
        root.authenticationError = true;
        root.message = "Could not complete sign-in. Press Retry.";
      }
    }
  }
  Common.Theme { id: theme; settings: Common.SettingsData }
  Common.SessionHint { id: hint }
  Component.onCompleted: {
    Quickshell.watchFiles = false;
    Common.UserData.refresh();
    hint.begin(ok => {
      root.privacyPrepared = ok;
      if (sessionLock.secure) hint.setLocked(true, () => {});
    });
  }
  IpcHandler {
    target: "lock"
    function lock(): void { sessionLock.locked = true; }
    function state(): string { return sessionLock.secure ? "secure" : "locking"; }
  }
  PamContext {
    id: pam
    // Unset user deliberately selects the real process user, not $USER/profile.
    config: "login"
    configDirectory: "/etc/pam.d"
    onPamMessage: {
      root.clearSecrets();
      if (messageIsError) {
        root.authenticationError = true;
        root.message = "The system rejected authentication.";
      }
      if (responseRequired) {
        root.starting = false;
        root.submitted = false;
        if (!root.authenticationError) root.message = "";
      }
    }
    onActiveChanged: root.clearSecrets()
    onCompleted: result => {
      const canRetry = root.submitted && result === PamResult.Failed;
      root.clearSecrets();
      root.starting = false;
      root.submitted = false;
      if (result === PamResult.Success && sessionLock.secure) {
        root.authenticated = true;
        root.authenticationError = false;
        root.message = "Access confirmed.";
        unlockAnimation.start();
      } else {
        root.authenticationError = true;
        root.message = result === PamResult.Failed ? "Incorrect password. Try again."
          : result === PamResult.MaxTries ? "Too many attempts. Wait before retrying."
          : "Could not authenticate. Press Retry.";
        if (canRetry) retryPrompt.start();
      }
    }
  }
  SystemClock { id: clock; precision: SystemClock.Minutes }
  WlSessionLock {
    id: sessionLock
    // Also starts locked after an explicit reload or a fresh recovery process.
    locked: true
    onSecureChanged: {
      root.clearSecrets();
      if (secure) {
        if (root.privacyPrepared) hint.setLocked(true, () => {});
        root.startAuthentication(false);
      }
    }
    WlSessionLockSurface {
      id: surface
      color: theme.background
      LockContent {
        id: content
        anchors.fill: parent
        tokens: theme
        settings: Common.SettingsData
        media: Common.MediaData
        displayName: Common.SettingsData.value.profile.name || Common.UserData.displayName
        avatar: Common.SettingsData.value.profile.image || Common.UserData.avatar
        dateTime: clock.date
        secure: sessionLock.secure
        busy: root.busy
        promptReady: pam.active && pam.responseRequired && !root.busy
        unlocking: root.authenticated
        exitProgress: root.exitProgress
        error: root.authenticationError
        message: root.message
        busyDetail: root.waitingSeconds >= 4 ? "The system is still verifying. A security delay may apply."
          : "Checking your password securely."
        onBegin: root.startAuthentication(false)
        onRespond: field => root.sendResponse(field.text)
        Connections { target: root; function onClearSecrets() { content.clear(); } }
      }
    }
  }
}
