pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Design

// Segmented control for a card's lists. Labels carry their own counts so the
// control stays on one line at panel width.
Rectangle {
  id: root
  required property Design.Theme tokens
  property color accent: tokens.cyan
  property var options: []
  property string current: ""
  signal selected(string key)
  Layout.fillWidth: true
  implicitHeight: 38
  radius: tokens.rowRadius
  color: tokens.sunken
  border.color: tokens.hairline

  RowLayout {
    anchors.fill: parent
    anchors.margins: 4
    spacing: 4
    Repeater {
      model: root.options
      Button {
        id: tab
        required property var modelData
        readonly property bool current: root.current === tab.modelData.key
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
        implicitHeight: 30
        padding: 0
        focusPolicy: Qt.StrongFocus
        Accessible.name: tab.modelData.label
        Accessible.role: Accessible.RadioButton
        Accessible.checkable: true
        Accessible.checked: tab.current
        onClicked: root.selected(tab.modelData.key)
        contentItem: Text {
          text: tab.modelData.label
          textFormat: Text.PlainText
          elide: Text.ElideRight
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          color: tab.current ? root.accent : root.tokens.muted
          font { family: root.tokens.font; pixelSize: 12; weight: tab.current ? Font.Medium : Font.Normal }
        }
        background: Rectangle {
          radius: root.tokens.rowRadius - 2
          color: tab.current ? root.tokens.raised
            : tab.hovered ? Qt.alpha(root.tokens.text, 0.05) : "transparent"
          border.width: tab.activeFocus ? 2 : tab.current ? 1 : 0
          border.color: tab.activeFocus ? root.tokens.cyan
            : tab.current ? root.tokens.border : "transparent"
          Rectangle {
            visible: tab.current
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 10; rightMargin: 10 }
            height: 2
            radius: 1
            color: root.accent
          }
        }
      }
    }
  }
}
