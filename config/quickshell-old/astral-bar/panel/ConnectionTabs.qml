pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../design" as Design

// Segmented switch for a card's two lists. Labels carry their own counts so
// the control stays a single line at panel width.
Rectangle {
  id: root
  required property Design.Theme tokens
  property color accent: tokens.cyan
  property var options: []
  property string current: ""
  signal selected(string key)
  Layout.fillWidth: true
  implicitHeight: 36
  radius: 9
  color: Qt.alpha(tokens.surface, 0.55)
  border.color: tokens.border

  RowLayout {
    anchors.fill: parent
    anchors.margins: 3
    spacing: 3
    Repeater {
      model: root.options
      Button {
        id: tab
        required property var modelData
        readonly property bool current: root.current === tab.modelData.key
        Layout.fillWidth: true
        Layout.fillHeight: true
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
          font { family: root.tokens.font; pixelSize: 10; weight: tab.current ? Font.Medium : Font.Normal }
        }
        background: Rectangle {
          radius: 6
          color: tab.current ? Qt.alpha(root.accent, 0.16)
            : tab.hovered ? Qt.alpha(root.accent, 0.06) : "transparent"
          border.color: tab.activeFocus ? root.accent
            : tab.current ? Qt.alpha(root.accent, 0.42) : "transparent"
        }
      }
    }
  }
}
