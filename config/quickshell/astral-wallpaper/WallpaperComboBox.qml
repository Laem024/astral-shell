pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ComboBox {
  id: control
  required property var tokens
  implicitWidth: Math.max(168, implicitContentWidth + 64)
  implicitHeight: 38
  leftPadding: 14; rightPadding: 40
  hoverEnabled: true
  font.family: tokens.font
  font.pixelSize: 13
  opacity: enabled ? 1 : 0.45
  background: Rectangle {
    radius: 10
    color: control.tokens.sunken
    border.width: control.activeFocus || control.popup.visible ? 2 : 1
    border.color: control.activeFocus || control.popup.visible ? control.tokens.cyan
      : control.hovered ? Qt.alpha(control.tokens.cyan, 0.5) : control.tokens.border
    Behavior on border.color { ColorAnimation { duration: control.tokens.hoverDuration } }
  }
  contentItem: Text {
    text: control.displayText; font: control.font; color: control.tokens.text
    verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
  }
  indicator: Text {
    x: control.width - width - 14; y: (control.height - height) / 2
    text: control.popup.visible ? "⌃" : "⌄"
    color: control.tokens.cyan; font.pixelSize: 16
  }
  delegate: ItemDelegate {
    id: option
    required property int index
    required property var modelData
    width: control.popup.availableWidth
    height: 38
    highlighted: control.highlightedIndex === index
    leftPadding: 12; rightPadding: 12
    contentItem: Item {
      Text {
        anchors { left: parent.left; right: check.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
        text: option.modelData; font: control.font
        color: option.index === control.currentIndex ? control.tokens.cyan : control.tokens.text
        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
      }
      Text {
        id: check
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        visible: option.index === control.currentIndex
        text: "✓"; color: control.tokens.cyan; font.pixelSize: 13
      }
    }
    background: Rectangle {
      radius: 8
      color: option.highlighted ? Qt.alpha(control.tokens.cyan, 0.14) : "transparent"
      border.width: option.activeFocus ? 1 : 0
      border.color: control.tokens.cyan
    }
  }
  popup: Popup {
    y: control.height + 6
    width: control.width
    implicitHeight: Math.min(contentItem.implicitHeight + 12, 280)
    padding: 6
    background: Rectangle { color: control.tokens.surface; radius: 14; border.width: 1; border.color: control.tokens.border }
    contentItem: ListView {
      clip: true; implicitHeight: contentHeight
      model: control.popup.visible ? control.delegateModel : null
      currentIndex: control.highlightedIndex
      ScrollIndicator.vertical: ScrollIndicator {}
    }
  }
}
