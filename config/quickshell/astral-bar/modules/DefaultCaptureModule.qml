pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../../common" as Design
import "../components" as Components

AbstractButton {
  id: root
  objectName: "recordingIndicator"
  required property Design.Theme tokens
  property bool vertical: false
  property bool compact: false
  property bool recording: false
  property string captureKind: "record"
  readonly property bool recordingVideo: recording && captureKind === "record"
  property string captureState: "idle"
  property int duration: 0
  readonly property bool showElapsed: recordingVideo && ["recording", "finalizing"].includes(captureState)
  readonly property color ink: recording ? tokens.alert : hovered ? tokens.lavender : tokens.cyan
  readonly property string elapsed: Math.floor(duration / 60).toString().padStart(2, "0") + ":" + (duration % 60).toString().padStart(2, "0")
  readonly property string detail: recording
    ? (({hiding: "Preparing capture", selecting: "Selecting source", preparing: captureKind === "shot" ? "Preparing screenshot" : "Preparing recording", recording: "Recording · " + elapsed, finalizing: captureKind === "shot" ? "Finishing screenshot" : "Finishing recording"})[captureState] || "Capture in progress") + (captureKind === "shot" ? " · Cancel capture" : " · Stop")
    : "Screen & capture"
  // Keep the shortcut compact, with room for the timer in either orientation.
  implicitWidth: vertical ? 48 : compact ? 34 : 40
  implicitHeight: vertical ? 38 : 40
  padding: 0
  Accessible.name: detail
  focusPolicy: Qt.StrongFocus
  background: Item {
    Rectangle {
      objectName: "captureKeyboardFocus"
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      width: 20; height: 2; radius: 1
      color: root.ink
      visible: root.visualFocus
    }
  }
  contentItem: Item {
    Item {
      id: captureContent
      objectName: "captureContent"
      anchors.centerIn: parent
      anchors.alignWhenCentered: false
      width: parent.width
      height: root.showElapsed ? 37 : 24
      Item {
        objectName: "captureInstrument"
        width: 24; height: 24
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        Components.CaptureGlyph {
          objectName: "captureGlyph"
          anchors.centerIn: parent
          visible: !root.recordingVideo
          ink: root.ink
        }
        Rectangle {
          id: recordingRing
          objectName: "recordingStopGlyph"
          visible: root.recordingVideo
          anchors.centerIn: parent
          width: 20; height: 20; radius: 4
          color: "transparent"
          Rectangle {
            anchors.centerIn: parent
            width: 10; height: width
            radius: 1
            color: root.ink
          }
          SequentialAnimation on opacity {
            running: root.recordingVideo && root.captureState === "recording" && root.tokens.settings.value.animations && !root.hovered
            loops: Animation.Infinite
            NumberAnimation { to: 0.5; duration: 800; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
            onRunningChanged: if (!running) recordingRing.opacity = 1
          }
        }
      }
      Text {
        visible: root.showElapsed
        x: 0
        y: 24
        width: parent.width
        objectName: "captureElapsed"
        text: root.elapsed
        color: root.recording ? root.ink : root.tokens.text
        height: 13
        font { family: root.tokens.mono; pixelSize: 11 }
        fontSizeMode: Text.HorizontalFit
        minimumPixelSize: 7
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
      }
    }
  }
}
