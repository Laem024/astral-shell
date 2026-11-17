pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

ComboBox {
  id: root
  required property var tokens
  implicitHeight: 38
  leftPadding: 12; rightPadding: 32
  font.family: tokens.font
  font.pixelSize: 12
  opacity: enabled ? 1 : 0.45
  contentItem: Text {
    text: root.displayText
    color: root.tokens.text
    font: root.font
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
  }
  indicator: Text {
    x: root.width - width - 12; anchors.verticalCenter: parent.verticalCenter
    text: '⌄'; color: root.tokens.muted; font.pixelSize: 16
  }
  background: Rectangle {
    radius: root.tokens.rowRadius
    color: root.hovered ? root.tokens.raised : root.tokens.sunken
    border.color: root.activeFocus ? root.tokens.cyan : root.tokens.border
    border.width: root.activeFocus ? 2 : 1
  }
  delegate: ItemDelegate {
    id: option
    required property int index
    required property var modelData
    width: root.width
    implicitHeight: 36
    highlighted: root.highlightedIndex === index
    contentItem: Text {
      text: String(option.modelData) || 'Default'
      color: option.highlighted ? root.tokens.cyan : root.tokens.text
      font: root.font
      elide: Text.ElideRight
      verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
      radius: root.tokens.rowRadius
      color: option.highlighted ? Qt.alpha(root.tokens.cyan, 0.12) : 'transparent'
    }
  }
  popup: Popup {
    y: root.height + 4
    width: root.width
    padding: 6
    implicitHeight: Math.min(contentItem.implicitHeight + 12, 280)
    contentItem: ListView {
      clip: true
      implicitHeight: contentHeight
      model: root.popup.visible ? root.delegateModel : null
      currentIndex: root.highlightedIndex
      ScrollIndicator.vertical: ScrollIndicator {}
    }
    background: Rectangle { radius: root.tokens.cardRadius; color: root.tokens.surface; border.color: root.tokens.border }
  }
}
