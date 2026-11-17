pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Services.SystemTray
import "../../common" as Design

FocusScope {
  id: root
  required property Design.Theme tokens
  required property var items
  property var selectedApp: null
  readonly property bool menuOpen: selectedApp !== null && selectedApp.hasMenu
  readonly property int count: items.values.length
  readonly property int columns: Math.max(1, Math.min(4, Math.floor((width + 8) / 56)))
  // One row of cells must match the viewport exactly, or the scroll bar appears
  // even when every icon fits.
  implicitHeight: menuOpen && menuLoader.item ? (menuLoader.item as Item).implicitHeight : 44 + (count === 0 ? 64 : Math.ceil(count / columns) * 72)
  signal closeRequested()
  focus: true

  Text {
    width: Math.max(0, parent.width - 32)
    text: "Background apps"; textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.tokens.text; font.family: root.tokens.font
    font.pixelSize: root.tokens.labelSize; font.bold: true
  }
  Text {
    anchors.right: parent.right
    text: root.count; color: root.tokens.cyan
    font.family: root.tokens.font; font.pixelSize: root.tokens.labelSize
  }
  Rectangle { y: 28; width: parent.width; height: 1; color: root.tokens.border }
  Text {
    y: 44; width: parent.width; height: 64
    visible: root.count === 0
    text: "No background applications"; textFormat: Text.PlainText
    wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    color: root.tokens.muted; font.family: root.tokens.font
    font.pixelSize: root.tokens.textSize
  }
  // A positioner would leave dynamically registered tray icons stacked at
  // (0, 0) on current Qt; a grid view lays them out and scrolls on demand.
  GridView {
    id: viewport
    y: 44; width: parent.width; height: Math.max(0, parent.height - y)
    visible: root.count > 0 && !root.menuOpen
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    cellWidth: width / root.columns; cellHeight: 72
    // Cells stretch with the viewport. Centering with a leftMargin instead made
    // GridView keep a stale negative contentX when the panel shrank from a
    // wider submenu, pushing every icon off the right edge.
    cacheBuffer: 10000
    // Tray lists are short; keeping delegates alive preserves keyboard traversal.
    ScrollBar.vertical: ScrollBar {}
    model: root.items
    delegate: Item {
      id: app
      required property SystemTrayItem modelData
      required property int index
      readonly property string label: modelData.title || modelData.tooltipTitle || modelData.id || "Application"
      // Cells span the viewport, so the visible plate is centered inside one.
      width: viewport.cellWidth; height: 48
      activeFocusOnTab: true
      Accessible.role: Accessible.Button
      Accessible.name: label
      Accessible.onPressAction: app.activate()
      function openMenu(): void {
        if (modelData.hasMenu) root.selectedApp = modelData;
      }
      function activate(): void {
        if (modelData.onlyMenu) openMenu();
        else modelData.activate();
      }
      onActiveFocusChanged: if (activeFocus) viewport.positionViewAtIndex(index, GridView.Contain)
      Keys.onReturnPressed: activate()
      Keys.onEnterPressed: activate()
      Keys.onSpacePressed: activate()
      Keys.onMenuPressed: openMenu()
      Keys.onPressed: event => {
        if (event.key === Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier)) {
          openMenu(); event.accepted = true;
        }
      }
      Keys.onEscapePressed: {
        if (root.menuOpen) root.selectedApp = null;
        else root.closeRequested();
      }
      Item {
        anchors.centerIn: parent
        width: 48; height: 48
        Rectangle {
          anchors.fill: parent; radius: root.tokens.rowRadius
          color: hover.hovered || app.activeFocus || root.menuOpen ? Qt.alpha(root.tokens.text, 0.08) : "transparent"
          border.width: app.activeFocus ? 2 : 0
          border.color: root.tokens.cyan
          Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
        }
        Image {
          id: icon
          anchors.centerIn: parent; width: 24; height: 24
          source: app.modelData.icon; sourceSize: Qt.size(24 * root.tokens.scale, 24 * root.tokens.scale); fillMode: Image.PreserveAspectFit
        }
        Text {
          anchors.centerIn: parent; visible: icon.status !== Image.Ready
          text: app.label.slice(0, 1).toUpperCase(); textFormat: Text.PlainText
          color: root.tokens.cyan; font.family: root.tokens.font; font.pixelSize: 20
        }
        Rectangle {
          visible: app.modelData.status === Status.NeedsAttention
          anchors.right: parent.right; anchors.top: parent.top
          anchors.margins: 4; width: 6; height: 6; radius: 3
          color: root.tokens.alert
        }
      }
      HoverHandler { id: hover }
      TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (eventPoint, button) => {
          app.forceActiveFocus();
          if (button === Qt.RightButton) app.openMenu();
          else app.activate();
        }
      }
      Text {
        anchors.top: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, app.width - 8); text: app.label; textFormat: Text.PlainText
        elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
        color: root.tokens.muted; font.family: root.tokens.font; font.pixelSize: 10
      }
      Component.onDestruction: if (root.selectedApp === modelData) root.selectedApp = null
    }
  }
  Loader {
    id: menuLoader
    anchors.fill: parent
    focus: active
    active: root.menuOpen
    sourceComponent: Component {
      TrayMenu {
        tokens: root.tokens
        handle: root.selectedApp ? root.selectedApp.menu : null
        title: root.selectedApp ? (root.selectedApp.title || root.selectedApp.id) : ""
        onBackRequested: root.selectedApp = null
        onDismissed: root.selectedApp = null
      }
    }
  }
}
