pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import "../../common" as Design

FocusScope {
  id: root
  required property Design.Theme tokens
  required property var handle
  required property string title
  property var selected: null
  onSelectedChanged: {
    if (selected) childLoader.setSource(Qt.resolvedUrl("TrayMenu.qml"), {tokens: tokens, handle: selected, title: selected.text});
    else childLoader.source = "";
  }
  signal backRequested()
  signal dismissed()
  readonly property int count: opener.children.values.length
  readonly property int emptyHeight: 17
  implicitHeight: childLoader.item ? (childLoader.item as Item).implicitHeight
    : 44 + (count === 0 ? emptyHeight : scroll.contentHeight)
  focus: true
  function back(): void {
    if (selected) { selected = null; backButton.forceActiveFocus(); }
    else backRequested();
  }
  Keys.onEscapePressed: back()
  QsMenuOpener { id: opener; menu: root.handle }
  Rectangle { anchors.fill: parent; color: root.tokens.surface }
  Item {
    anchors.fill: parent
    visible: !root.selected
    Button {
      id: backButton
      width: 28; height: 28; text: "‹"; focus: true
      Accessible.name: "Back"
      onClicked: root.backRequested()
      background: Rectangle {
        radius: root.tokens.rowRadius
        color: backButton.hovered ? Qt.alpha(root.tokens.text, 0.08) : "transparent"
        border.width: backButton.activeFocus ? 2 : 0
        border.color: root.tokens.cyan
      }
      contentItem: Text { text: backButton.text; color: root.tokens.cyan; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
    }
    Text {
      x: 36; width: Math.max(0, parent.width - x); height: 28
      text: root.title; textFormat: Text.PlainText; elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
      color: root.tokens.text; font.family: root.tokens.font; font.pixelSize: root.tokens.labelSize
    }
    Rectangle { y: 35; width: parent.width; height: 1; color: root.tokens.border }
    Text {
      y: 44; width: parent.width; height: root.emptyHeight
      visible: root.count === 0
      text: "No actions available"; textFormat: Text.PlainText
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      color: root.tokens.muted; font.family: root.tokens.font; font.pixelSize: root.tokens.textSize
    }
    // A positioner would leave dynamically loaded menu rows stacked at y=0 on
    // current Qt; a list view lays them out and reports its content height.
    ListView {
      id: scroll
      y: 44; width: parent.width; height: Math.max(0, parent.height - y)
      visible: root.count > 0
      clip: true
      model: opener.children
      spacing: 2
      boundsBehavior: Flickable.StopAtBounds
      // Menus are short; keeping delegates alive preserves keyboard traversal.
      cacheBuffer: 10000
      ScrollBar.vertical: ScrollBar {}
      delegate: Loader {
        id: entry
        required property QsMenuEntry modelData
        required property int index
        width: scroll.width; height: modelData.isSeparator ? 9 : 36
        sourceComponent: modelData.isSeparator ? separator : menuAction
        Component {
          id: separator
          Item {
            // Decorative rows have no button, pointer handling or keyboard focus.
            Rectangle { anchors.centerIn: parent; width: parent.width - 12; height: 1; color: root.tokens.border }
          }
        }
        Component {
          id: menuAction
          Button {
            id: action
            readonly property QsMenuEntry modelData: entry.modelData
            enabled: modelData.enabled
            activeFocusOnTab: enabled
            text: modelData.text
            Accessible.name: text
            onActiveFocusChanged: if (activeFocus) scroll.positionViewAtIndex(entry.index, ListView.Contain)
            onClicked: {
              if (modelData.hasChildren) root.selected = modelData;
              else { modelData.triggered(); root.dismissed(); }
            }
            background: Rectangle {
              radius: root.tokens.rowRadius
              color: action.hovered ? Qt.alpha(root.tokens.text, 0.08) : "transparent"
              border.width: action.activeFocus ? 2 : 0
              border.color: root.tokens.cyan
            }
            contentItem: Item {
              opacity: action.enabled ? 1 : 0.45
              Text {
                x: 4; width: 20; height: parent.height
                text: action.modelData.buttonType === QsMenuButtonType.None ? "" : action.modelData.checkState === Qt.Checked ? (action.modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : "✓") : action.modelData.checkState === Qt.PartiallyChecked ? "−" : ""
                color: root.tokens.cyan; verticalAlignment: Text.AlignVCenter
              }
              Image {
                x: 4; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16
                visible: action.modelData.buttonType === QsMenuButtonType.None
                source: action.modelData.icon; sourceSize: Qt.size(16 * root.tokens.scale, 16 * root.tokens.scale)
                fillMode: Image.PreserveAspectFit
              }
              Text {
                x: 28; width: Math.max(0, parent.width - 44); height: parent.height
                text: action.text.replace(/&&/g, "\u0001").replace(/&/g, "").replace(/\u0001/g, "&")
                textFormat: Text.PlainText; elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                color: root.tokens.text; font.family: root.tokens.font; font.pixelSize: root.tokens.textSize
              }
              Text { anchors.right: parent.right; height: parent.height; text: action.modelData.hasChildren ? "›" : ""; color: root.tokens.cyan; verticalAlignment: Text.AlignVCenter }
            }
          }
        }
      }
    }
  }
  Loader {
    id: childLoader
    anchors.fill: parent
    focus: active
    active: root.selected !== null
    Connections {
      target: childLoader.item
      function onBackRequested(): void { root.back(); }
      function onDismissed(): void { root.dismissed(); }
    }
  }
}
