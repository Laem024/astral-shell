import QtQuick
import Quickshell

// Substitute only the layer surface when checking QML without a compositor.
FloatingWindow {
  property HeadlessAnchors anchors: HeadlessAnchors {}
  property HeadlessMargins margins: HeadlessMargins {}
  property int exclusionMode: 0
  property real exclusiveZone: 0
  property bool aboveWindows: true
  property bool focusable: false
}
