pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

Item {
  id: root
  property real radius: 8
  default property alias content: contentItem.data
  Rectangle {
    id: mask
    anchors.fill: parent
    radius: root.radius
    color: "white"
    visible: false
    layer.enabled: true
  }
  Item {
    id: contentItem
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: mask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }
  }
}
