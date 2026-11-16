import QtQuick
import "../design" as Design

Item {
  id: root
  required property Design.Theme tokens
  property bool vertical: false
  implicitWidth: vertical ? 32 : 10
  implicitHeight: vertical ? 10 : 32
  Rectangle {
    anchors.centerIn: parent
    width: root.vertical ? 24 : 1
    height: root.vertical ? 1 : 24
    color: root.tokens.border
  }
}
