import QtQuick
import "../common" as Design
import "FrameLogic.js" as Logic

QtObject {
  required property var settings
  required property Design.Theme tokens
  readonly property var metrics: Logic.calculate(settings.value, tokens)
  readonly property string mode: metrics.mode
  readonly property bool active: metrics.active
  readonly property string edge: metrics.edge
  readonly property bool vertical: metrics.vertical
  readonly property real margin: metrics.margin
  readonly property real thickness: metrics.thickness
  readonly property real radius: metrics.radius
  readonly property real barSize: metrics.barSize
  function reservation(side: string): real { return metrics.reservation(side); }
  function base(side: string): real { return metrics.base(side); }
}
