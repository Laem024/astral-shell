pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../../config/quickshell/astral-bar/data" as Data

ShellRoot {
  id: root
  Data.NotificationService { id: service }
  property bool quiet: false
  Data.NotificationSoundPolicy { id: soundPolicy; active: root.quiet }
  QtObject {
    id: alertStream
    property var properties: ({"media.role": "Notification"})
    property var audio: QtObject { property bool muted: false }
  }
  QtObject {
    id: mutedEvent
    property var properties: ({"media.role": "event"})
    property var audio: QtObject { property bool muted: true }
  }
  QtObject {
    id: musicStream
    property var properties: ({"media.role": "Music"})
    property var audio: QtObject { property bool muted: false }
  }
  QtObject {
    id: callStream
    property var properties: ({"media.role": "Communication"})
    property var audio: QtObject { property bool muted: false }
  }
  QtObject {
    id: lateAlert
    property var properties: ({"media.role": "event"})
    property var audio: QtObject { property bool muted: false }
  }
  function check(value, message): void {
    if (!value) throw new Error(message);
  }
  IpcHandler {
    target: "test"
    function inspect(stage: string): string {
      try {
        const e = service.entries[0];
        if (stage === "sound-enable") {
          soundPolicy.nodes = [alertStream, mutedEvent, musicStream, callStream];
          root.quiet = true;
        } else if (stage === "sound-muted") {
          root.check(alertStream.audio.muted && mutedEvent.audio.muted, "notification sounds muted");
          root.check(!musicStream.audio.muted && !callStream.audio.muted, "media and calls unchanged");
          soundPolicy.nodes = [alertStream, mutedEvent, musicStream, callStream, lateAlert];
        } else if (stage === "sound-late") {
          root.check(lateAlert.audio.muted && alertStream.audio.muted, "new notification stream muted");
          root.quiet = false;
        } else if (stage === "sound-restored") {
          root.check(!alertStream.audio.muted && mutedEvent.audio.muted && !lateAlert.audio.muted, "original mute states restored");
          root.check(!musicStream.audio.muted && !callStream.audio.muted, "media and calls preserved");
        } else if (stage === "receive") {
          root.check(service.entries.length === 1 && service.unread === 1 && e.summary === "First", "receive / unread");
          root.check(service.popups[0].remaining === -1, "never expires");
        } else if (stage === "replace") {
          root.check(service.entries.length === 1 && e.summary === "Replaced" && e.actions[0].id === "open", "replacement");
          service.hide(e.id);
          root.check(service.popups.length === 0 && !!e.live, "hide preserves live actions");
          service.readers = 1;
          root.check(service.unread === 0, "read on show");
        } else if (stage === "action-label") {
          const replaced = service.entries.find(item => item.summary === "Replaced");
          root.check(replaced.actions[0].text === "Updated action", "replacement action text");
        } else if (stage === "reading") {
          root.check(service.unread === 0 && service.entries.length === 2, "read while visible");
          service.readers = 0;
          service.dnd = true;
          root.check(service.popups.length === 0, "dnd hides all");
        } else if (stage === "dnd") {
          root.check(service.entries.length === 3 && service.unread === 1 && service.popups.length === 0, "dnd retains history");
          service.dnd = false;
        } else if (stage === "lock-start") {
          service.sessionBlocked = true;
          root.check(!service.dnd && service.popups.length === 0, "lock hides without DND change");
        } else if (stage === "lock-notification") {
          root.check(service.popups.length === 0 && !service.dnd, "lock suppresses new popup");
          const lockedEntry = service.entries.find(item => item.summary === "While locked");
          root.check(!!lockedEntry, "lock retains notification history");
          service.remove(lockedEntry.id);
          service.sessionBlocked = false;
          root.check(!service.dnd && service.popups.length === 0, "unlock preserves DND and avoids replay");
        } else if (stage === "transient") {
          root.check(service.entries.length === 3 && service.popups.length === 1, "transient no history");
          service.pause(service.popups[0].id, true);
        } else if (stage === "paused") {
          root.check(service.popups.length === 1, "pause timer");
          service.pause(service.popups[0].id, false);
        } else if (stage === "expired") {
          root.check(service.popups.length === 0 && service.entries.length === 3, "transient expiry");
        } else if (stage === "closed") {
          root.check(e.summary === "DND" && !e.live && e.actions.length === 0, "sender close invalidates actions");
        } else if (stage === "action") {
          service.invoke(e.id, "open");
          root.check(!service.entries[0].live && service.entries[0].actions.length === 0, "action closes nonresident");
        } else if (stage === "resident") {
          service.invoke(e.id, "open");
          root.check(!!service.entries[0].live, "resident retained");
          service.remove(e.id);
          root.check(!service.entries.some(item => item.id === e.id), "delete");
          service.clear();
          root.check(service.entries.length === 0 && service.unread === 0, "clear");
        } else if (stage === "limit") {
          root.check(service.entries.length === 100 && service.popups.length === 3, "bounded history and popups");
          service.clear();
        } else if (stage === "critical") {
          root.check(service.popups.length === 1 && service.popups[0].remaining === -1, "critical ignores timeout");
          service.clear();
        } else if (stage === "default-timeout") {
          root.check(service.popups.length === 1 && service.popups[0].remaining > 5500
            && service.popups[0].remaining <= 6000, "default six seconds");
          root.check(!service.canOpen(e), "no default or valid desktop entry");
          service.clear();
        } else if (stage === "default-action") {
          root.check(service.canOpen(e), "default action available");
          service.open(e.id);
          root.check(!service.entries[0].live, "default action invoked");
          service.clear();
        } else if (stage === "normal-expired") {
          root.check(service.popups.length === 0 && !!e.live, "normal timeout preserves actions");
          service.clear();
        } else throw new Error("unknown stage");
        return "PASS " + stage;
      } catch (error) { return "FAIL " + error; }
    }
  }
}
