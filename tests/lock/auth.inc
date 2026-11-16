  property var testView: null
  property int testStage: 0
  property int startsAtFailure: 0
  property bool sawExitFrame: false
  function testCheck(value: bool, message: string): void { if (!value) throw new Error(message); }
  function testField(item: var): var {
    if (item.objectName === "lockPassword") return item;
    for (const child of item.children || []) { const found = testField(child); if (found) return found; }
    return null;
  }
  Timer {
    interval: root.testStage === 0 ? 1500 : 40; running: true; repeat: true
    onTriggered: {
      try {
        const view = root.testView;
        const field = root.testField(view);
        if (root.testStage === 0) {
          root.testCheck(sessionLock.locked && sessionLock.secure, "initial lock");
          pam.active = false;
          view.begin();
          const starts = pam.starts;
          view.begin();
          root.testCheck(pam.starts === starts, "simultaneous PAM attempts");
          field.text = "test-only";
          view.submit();
          root.testCheck(root.busy && view.busy && !field.enabled && root.message === "Verifying password…", "immediate pending feedback");
          root.testCheck(pam.lastResponseLength === 9 && field.text === "", "nonempty response delivered before clearing");
          view.respond({text: "test-only"});
          root.testCheck(pam.responses === 1, "duplicate submission while responseRequired is stale");
          root.testStage = 1;
        } else if (root.testStage === 1) {
          root.testCheck(sessionLock.locked && root.busy, "PAM delay keeps lock");
          if (root.waitingSeconds < 4) return;
          root.testCheck(view.busyDetail.indexOf("security delay") >= 0, "long wait has visible explanation while event loop stays responsive");
          pam.responseRequired = false;
          pam.messageIsError = true;
          pam.pamMessage();
          root.testCheck(root.authenticationError && root.message.indexOf("rejected") >= 0, "PAM error feedback before completion");
          pam.finish(PamResult.Failed);
          root.testCheck(root.message.indexOf("Incorrect") >= 0 && sessionLock.locked, "incorrect password visible");
          root.testStage = 2;
        } else if (root.testStage === 2) {
          root.testCheck(view.promptReady && !view.busy && root.authenticationError && field.activeFocus, "automatic retry ready with error retained and focus");
          field.text = "test-only";
          view.submit();
          root.testCheck(!root.authenticationError && root.busy && pam.responses === 2, "retry clears error only on submit");
          pam.finish(PamResult.MaxTries);
          root.startsAtFailure = pam.starts;
          root.testStage = 3;
        } else if (root.testStage === 3) {
          root.testCheck(!root.busy && pam.starts === root.startsAtFailure && root.message.indexOf("Too many") >= 0, "lockout has no automatic retry loop");
          view.begin(); pam.finish(PamResult.Error);
          root.startsAtFailure = pam.starts;
          root.testStage = 4;
        } else if (root.testStage === 4) {
          root.testCheck(pam.starts === root.startsAtFailure && sessionLock.locked, "service error retains lock without retry loop");
          pam.failStart = true; view.begin();
          root.testCheck(!root.busy && root.authenticationError, "failed start recovers retry button");
          pam.failStart = false; view.begin();
          view.clear(); root.clearSecrets();
          root.testCheck(sessionLock.locked, "clear/Escape unlocked");
          sessionLock.secure = false;
          pam.finish(PamResult.Success);
          root.testCheck(sessionLock.locked, "unconfirmed compositor unlocked");
          sessionLock.secure = true;
          root.testStage = 5;
          pam.finish(PamResult.Success);
          if (Settings.SettingsData.value.animations) root.testCheck(sessionLock.locked && root.authenticated && view.unlocking && !field.enabled, "success keeps compositor locked during exit");
        } else if (root.testStage === 5) {
          root.testCheck(sessionLock.locked, "early unlock during exit");
          if (root.exitProgress > 0 && root.exitProgress < 1) root.sawExitFrame = true;
        }
      } catch (error) { console.log("AUTH_FAIL", error); Qt.quit(); }
    }
  }
  Connections {
    target: sessionLock
    function onLockedChanged() {
      if (sessionLock.locked) return;
      try {
        root.testCheck(root.testStage === 5 && root.authenticated && root.exitProgress === 1, "unlock only after authenticated animation completion");
        root.testCheck(!Settings.SettingsData.value.animations || root.sawExitFrame, "animated exit rendered intermediate frames");
        root.testStage = 6;
        console.log("AUTH_PASS");
      } catch (error) { console.log("AUTH_FAIL", error); Qt.quit(); }
    }
  }
