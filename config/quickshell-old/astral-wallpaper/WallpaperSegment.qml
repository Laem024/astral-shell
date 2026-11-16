pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Compact segmented control for choices that deserve one click.
Rectangle {
  id: root
  required property var tokens
  property var options: []
  property int currentIndex: 0
  signal activated(int index)
  implicitWidth: row.implicitWidth + 8
  implicitHeight: 36
  radius: 9
  color: tokens.background
  border.color: tokens.border
  Row {
    id: row
    anchors.fill: parent
    anchors.margins: 4
    spacing: 4
    Repeater {
      model: root.options
      delegate: Button {
        id: segment
        required property string modelData
        required property int index
        width: Math.max(64, implicitContentWidth + leftPadding + rightPadding)
        height: row.height
        leftPadding: 14; rightPadding: 14
        font.family: root.tokens.font
        font.pixelSize: 12
        font.bold: root.currentIndex === index
        text: modelData
        onClicked: root.activated(index)
        Accessible.name: modelData
        Accessible.role: Accessible.RadioButton
        Accessible.checkable: true
        Accessible.checked: root.currentIndex === index
        background: Rectangle {
          radius: 6
          color: root.currentIndex === segment.index ? root.tokens.cyan
            : segment.hovered ? Qt.alpha(root.tokens.cyan, 0.1) : "transparent"
          border.width: root.currentIndex === segment.index ? 0 : 1
          border.color: root.tokens.border
        }
        contentItem: Text {
          text: segment.text
          font: segment.font
          color: root.currentIndex === segment.index ? root.tokens.background : root.tokens.text
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }
      }
    }
  }
}
