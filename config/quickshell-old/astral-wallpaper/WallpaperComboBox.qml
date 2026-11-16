pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ComboBox {
  id: control
  required property var tokens
  implicitWidth: Math.max(160, implicitContentWidth + 58)
  implicitHeight: 38
  leftPadding: 12; rightPadding: 36
  font.family: tokens.font
  font.pixelSize: 12
  opacity: enabled ? 1 : 0.45
  background: Rectangle {
    radius: 9
    color: control.hovered ? Qt.alpha(control.tokens.cyan, 0.08) : control.tokens.background
    border.color: control.activeFocus || control.popup.visible ? control.tokens.cyan : control.tokens.border
  }
  contentItem: Text {
    text: control.displayText; font: control.font; color: control.tokens.text
    verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
  }
  indicator: Text {
    x: control.width - width - 13; y: (control.height - height) / 2
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
    contentItem: Text {
      text: option.modelData; font: control.font
      color: option.index === control.currentIndex ? control.tokens.cyan : control.tokens.text
      verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
    }
    background: Rectangle {
      radius: 6
      color: option.highlighted ? Qt.alpha(control.tokens.cyan, 0.14) : "transparent"
    }
  }
  popup: Popup {
    y: control.height + 6
    width: control.width
    implicitHeight: Math.min(contentItem.implicitHeight + 12, 260)
    padding: 6
    background: Rectangle { color: control.tokens.surface; radius: 10; border.color: control.tokens.border }
    contentItem: ListView {
      clip: true; implicitHeight: contentHeight
      model: control.popup.visible ? control.delegateModel : null
      currentIndex: control.highlightedIndex
      ScrollIndicator.vertical: ScrollIndicator {}
    }
  }
}
