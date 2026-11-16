pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "data" as Data

Scope {
  id: root
  required property var settings
  required property var service
  required property var tokens

  readonly property bool opened: service.active && !Data.SessionData.blocked
  property var monitor: Quickshell.screens[0] || null
  property real reveal: opened ? 1 : 0

  Behavior on reveal {
    NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic }
  }

  function focusInput(): void {
    // qmllint disable missing-property
    if (surface.item) surface.item.focusInput();
  }

  onOpenedChanged: {
    if (!opened) return;
    const active = Hyprland.focusedMonitor;
    root.monitor = Quickshell.screens.find(s => active && s.name === active.name)
      || Quickshell.screens[0] || null;
    Qt.callLater(root.focusInput);
  }

  Connections {
    target: Quickshell
    function onScreensChanged(): void {
      if (!Quickshell.screens.includes(root.monitor)) root.monitor = Quickshell.screens[0] || null;
    }
  }

  // The surface is created per request so the layer shell maps it with
  // exclusive keyboard focus from the start.
  LazyLoader {
    id: surface
    active: root.opened || root.reveal > 0
    component: Component {
      PolkitSurface {
        settings: root.settings
        service: root.service
        tokens: root.tokens
        monitor: root.monitor
        reveal: root.reveal
        onCancelRequested: root.service.cancel()
        onSubmitRequested: value => root.service.submit(value)
      }
    }
    // qmllint disable missing-property
    onItemChanged: if (item) item.focusInput()
  }
}
