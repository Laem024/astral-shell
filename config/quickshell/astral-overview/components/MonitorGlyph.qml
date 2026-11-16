import QtQuick

Item {
  id: root
  required property color ink
  implicitWidth: 20
  implicitHeight: 20
  Accessible.ignored: true

  Rectangle {
    x: 2
    y: 3
    width: 16
    height: 11
    radius: 2
    color: "transparent"
    border.color: root.ink
    border.width: 1.5
  }
  Rectangle {
    x: 9.25
    y: 14
    width: 1.5
    height: 3
    color: root.ink
  }
  Rectangle {
    x: 6
    y: 17
    width: 8
    height: 1.5
    radius: 0.75
    color: root.ink
  }
}
