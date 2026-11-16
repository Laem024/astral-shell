import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: root
  required property var modelData
  required property var service
  screen: modelData
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Background
  WlrLayershell.namespace: "astral-wallpaper"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}
  color: "#151918"
  WallpaperRenderer { anchors.fill: parent; service: root.service; modelData: root.modelData }
}
