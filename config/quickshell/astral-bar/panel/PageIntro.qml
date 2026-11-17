pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../common" as Design

// Each workspace opens with a readable title and a live service summary.
Rectangle {
  id: root
  required property Design.Theme tokens
  required property string title
  required property string subtitle
  property string symbol: "connections"
  property color accent: tokens.cyan
  Layout.fillWidth: true
  Layout.minimumHeight: implicitHeight
  implicitHeight: body.implicitHeight + 32
  radius: tokens.cardRadius
  gradient: Gradient {
    orientation: Gradient.Horizontal
    GradientStop { position: 0; color: Qt.tint(root.tokens.background, Qt.alpha(root.accent, 0.12)) }
    GradientStop { position: 1; color: root.tokens.background }
  }
  border.color: Qt.alpha(accent, 0.2)
  RowLayout {
    id: body
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
    spacing: 14
    Rectangle {
      Layout.preferredWidth: 44; Layout.preferredHeight: 44
      radius: 14
      color: Qt.alpha(root.accent, 0.12)
      CategoryGlyph { anchors.centerIn: parent; kind: root.symbol; ink: root.accent; width: 24; height: 24 }
    }
    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: 5
      Text {
        Layout.fillWidth: true
        text: root.title
        textFormat: Text.PlainText
        color: root.tokens.text
        wrapMode: Text.Wrap
        font { family: root.tokens.font; pixelSize: 20; weight: Font.DemiBold }
      }
      Text {
        Layout.fillWidth: true
        text: root.subtitle
        textFormat: Text.PlainText
        color: root.tokens.muted
        wrapMode: Text.Wrap
        font { family: root.tokens.font; pixelSize: 11 }
      }
    }
  }
}
