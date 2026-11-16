pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "design" as Design

Rectangle {
  id: root
  required property Design.Theme tokens
  required property var media
  implicitHeight: body.implicitHeight + 48
  color: tokens.surface
  radius: 20
  border.color: tokens.border
  function timestamp(seconds: real): string {
    const total = Math.max(0, Math.floor(seconds || 0));
    return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0");
  }
  component Transport: Button {
    id: control
    required property string glyph
    property bool primary: false
    implicitWidth: primary ? 52 : 40
    implicitHeight: primary ? 52 : 40
    focusPolicy: Qt.NoFocus
    contentItem: Text {
      text: control.glyph
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      color: control.primary ? root.tokens.background : root.tokens.text
      opacity: control.enabled ? 1 : 0.25
      font { family: root.tokens.mono; pixelSize: control.primary ? 19 : 15 }
    }
    background: Rectangle {
      radius: width / 2
      color: control.primary ? root.tokens.cyan : control.hovered && control.enabled ? Qt.alpha(root.tokens.cyan, 0.08) : "transparent"
      border.color: control.primary ? "transparent" : root.tokens.border
      opacity: control.enabled ? 1 : 0.4
    }
  }
  ColumnLayout {
    id: body
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
    spacing: 18
    RowLayout {
      Layout.fillWidth: true
      spacing: 10
      Rectangle { implicitWidth: 6; implicitHeight: 6; radius: 3; color: root.media.playing ? root.tokens.cyan : root.tokens.muted }
      Text {
        Layout.fillWidth: true
        text: root.media.playing ? "NOW PLAYING" : "PAUSED"
        color: root.tokens.muted
        font { family: root.tokens.mono; pixelSize: 10; letterSpacing: 1.5 }
      }
      Text { text: "♫"; color: root.tokens.gold; font.pixelSize: 18 }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 16
      // A local procedural record replaces remote artwork on the lock screen.
      Rectangle {
        Layout.preferredWidth: 68; Layout.preferredHeight: 68; radius: 14; color: root.tokens.background
        Rectangle {
          anchors.centerIn: parent
          width: 50; height: 50; radius: 25; color: root.tokens.surface
          border.color: root.tokens.border
          Repeater {
            model: [38, 28]
            Rectangle {
              required property int modelData
              anchors.centerIn: parent; width: modelData; height: width; radius: width / 2
              color: "transparent"; border.color: root.tokens.border
            }
          }
          Rectangle { anchors.centerIn: parent; width: 12; height: 12; radius: 6; color: root.tokens.gold }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 5
        Text {
          objectName: "lockTrackTitle"
          Layout.fillWidth: true
          text: root.media.title; textFormat: Text.PlainText; elide: Text.ElideRight
          color: root.tokens.text
          font { family: root.tokens.font; pixelSize: 19; weight: Font.DemiBold }
        }
        Text {
          Layout.fillWidth: true
          text: root.media.artist; textFormat: Text.PlainText; elide: Text.ElideRight
          color: root.tokens.muted
          font { family: root.tokens.font; pixelSize: 13 }
        }
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 7
      Rectangle {
        Layout.fillWidth: true; implicitHeight: 3; radius: 2
        color: Qt.alpha(root.tokens.muted, 0.15)
        Rectangle {
          width: parent.width * Math.max(0, Math.min(1, root.media.progress)); height: parent.height; radius: 2
          color: root.tokens.cyan
        }
      }
      RowLayout {
        Layout.fillWidth: true
        Text { text: root.timestamp(root.media.position); color: root.tokens.muted; font { family: root.tokens.mono; pixelSize: 10 } }
        Item { Layout.fillWidth: true }
        Text { text: root.media.length > 0 ? root.timestamp(root.media.length) : "—:—"; color: root.tokens.muted; font { family: root.tokens.mono; pixelSize: 10 } }
      }
    }
    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 18
      Transport { objectName: "lockPrevious"; glyph: "\uf048"; enabled: root.media.canPrevious; Accessible.name: "Previous"; onClicked: root.media.previous() }
      Transport { objectName: "lockPlay"; glyph: root.media.playing ? "\uf04c" : "\uf04b"; primary: true; enabled: root.media.canToggle; Accessible.name: root.media.playing ? "Pause" : "Play"; onClicked: root.media.toggle() }
      Transport { objectName: "lockNext"; glyph: "\uf051"; enabled: root.media.canNext; Accessible.name: "Next"; onClicked: root.media.next() }
    }
  }
}
