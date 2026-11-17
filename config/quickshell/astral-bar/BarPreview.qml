pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import "../common" as Common
import "settings" as Settings
import "panel" as Panel

// An ordinary window simulates one output; previews never reserve desktop space.
FloatingWindow {
  id: root
  title: "Astral bar frame preview"
  implicitWidth: 1280
  implicitHeight: 900
  color: theme.background
  property string frameMode: Settings.SettingsData.value.frame
  property string edge: Settings.SettingsData.value.position
  QtObject {
    id: previewSettings
    readonly property var value: Object.assign({}, Settings.SettingsData.value, {
      frame: root.frameMode, position: root.edge
    })
  }
  Common.Theme { id: theme; settings: previewSettings }
  FrameGeometry { id: frameGeometry; settings: previewSettings; tokens: theme }
  Panel.PanelState { id: previewNavigation }
  Row {
    id: controls
    spacing: 12
    x: 12; y: 12
    ComboBox {
      model: ["off", "folds", "full"]
      currentIndex: model.indexOf(root.frameMode)
      onActivated: root.frameMode = currentText
    }
    ComboBox {
      model: ["top", "bottom", "left", "right"]
      currentIndex: model.indexOf(root.edge)
      onActivated: { previewNavigation.close(); root.edge = currentText; }
    }
    Label { text: "Simulated output · close this window to exit"; color: theme.text; anchors.verticalCenter: parent.verticalCenter }
  }
  Item {
    id: output
    anchors { top: controls.bottom; topMargin: 12; left: parent.left; right: parent.right; bottom: parent.bottom }
    clip: true
    Rectangle {
      x: frameGeometry.reservation("left"); y: frameGeometry.reservation("top")
      width: Math.max(1, output.width - x - frameGeometry.reservation("right"))
      height: Math.max(1, output.height - y - frameGeometry.reservation("bottom"))
      color: theme.sunken
      border.color: theme.border
      Text { anchors.centerIn: parent; text: "Reserved application area"; color: theme.muted }
      MouseArea { anchors.fill: parent; onClicked: previewNavigation.close() }
    }
    Repeater {
      model: ["top", "bottom", "left", "right"]
      delegate: FrameDrawing {
        required property string modelData
        geometry: frameGeometry
        edge: modelData
        surfaceColor: theme.surface
        visible: frameGeometry.active && base > 0
        x: edge === "right" ? output.width - width : 0
        y: edge === "bottom" ? output.height - height : 0
        width: horizontal ? output.width : depth
        height: horizontal ? depth : output.height
      }
    }
    Rectangle {
      id: bar
      x: root.edge === "right" ? output.width - width - frameGeometry.margin : frameGeometry.margin
      y: root.edge === "bottom" ? output.height - height - frameGeometry.margin : frameGeometry.margin
      width: frameGeometry.vertical ? frameGeometry.barSize : output.width - 2 * frameGeometry.margin
      height: frameGeometry.vertical ? output.height - 2 * frameGeometry.margin : frameGeometry.barSize
      color: frameGeometry.active ? theme.surface : "transparent"
      BarContent {
        x: frameGeometry.vertical ? 0 : previewSettings.value.margin - frameGeometry.margin
        y: frameGeometry.vertical ? previewSettings.value.margin - frameGeometry.margin : 0
        width: (bar.width - 2 * x) / theme.scale
        height: (bar.height - 2 * y) / theme.scale
        scale: theme.scale; transformOrigin: Item.TopLeft
        settings: previewSettings; tokens: theme; navigation: previewNavigation
        vertical: frameGeometry.vertical
      }
    }
  }
}
