pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../common" as Common

Rectangle {
  id: root
  required property Common.Theme tokens
  required property var media
  implicitHeight: body.implicitHeight + 32
  color: tokens.surface
  radius: tokens.cardRadius
  border.color: tokens.border
  function timestamp(seconds: real): string {
    const total = Math.max(0, Math.floor(seconds || 0));
    return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0");
  }
  component Transport: Button {
    id: control
    required property string glyph
    property bool primary: false
    implicitWidth: primary ? 48 : 38
    implicitHeight: implicitWidth
    focusPolicy: Qt.NoFocus
    contentItem: Text {
      text: control.glyph
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      color: control.primary ? root.tokens.background : root.tokens.text
      font { family: root.tokens.mono; pixelSize: control.primary ? 17 : 14 }
    }
    background: Rectangle {
      radius: width / 2
      opacity: control.enabled ? 1 : 0.4
      color: control.primary ? (control.down ? Qt.alpha(root.tokens.cyan, 0.85) : control.hovered ? Qt.lighter(root.tokens.cyan, 1.08) : root.tokens.cyan)
        : control.hovered && control.enabled ? Qt.alpha(root.tokens.cyan, 0.12) : "transparent"
      border.width: 1
      border.color: control.primary ? "transparent"
        : control.hovered && control.enabled ? Qt.alpha(root.tokens.cyan, 0.45) : root.tokens.border
      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
      Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
    }
  }
  ColumnLayout {
    id: body
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
    spacing: 16
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Rectangle { implicitWidth: 6; implicitHeight: 6; radius: 3; color: root.media.playing ? root.tokens.cyan : root.tokens.muted }
      Text {
        Layout.fillWidth: true
        text: root.media.playing ? "NOW PLAYING" : "PAUSED"
        color: root.tokens.muted
        font { family: root.tokens.mono; pixelSize: 10; letterSpacing: 1.2 }
      }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 12
      // A local procedural record replaces remote artwork on the lock screen.
      Rectangle {
        Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: root.tokens.rowRadius
        color: root.tokens.sunken
        border.width: 1; border.color: root.tokens.border
        Rectangle {
          anchors.centerIn: parent
          width: 40; height: 40; radius: 20; color: root.tokens.surface
          border.color: root.tokens.border
          Repeater {
            model: [28, 18]
            Rectangle {
              required property int modelData
              anchors.centerIn: parent; width: modelData; height: width; radius: width / 2
              color: "transparent"; border.color: root.tokens.border
            }
          }
          Rectangle { anchors.centerIn: parent; width: 9; height: 9; radius: 5; color: root.tokens.gold }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2
        Text {
          objectName: "lockTrackTitle"
          Layout.fillWidth: true
          text: root.media.title; textFormat: Text.PlainText; elide: Text.ElideRight
          color: root.tokens.text
          font { family: root.tokens.font; pixelSize: 15; weight: Font.DemiBold }
        }
        Text {
          Layout.fillWidth: true
          text: root.media.artist; textFormat: Text.PlainText; elide: Text.ElideRight
          color: root.tokens.muted
          font { family: root.tokens.font; pixelSize: 12 }
        }
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6
      Rectangle {
        Layout.fillWidth: true; implicitHeight: 3; radius: 2
        color: Qt.alpha(root.tokens.muted, 0.18)
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
      spacing: 16
      Transport { objectName: "lockPrevious"; glyph: "\uf048"; enabled: root.media.canPrevious; Accessible.name: "Previous"; onClicked: root.media.previous() }
      Transport { objectName: "lockPlay"; glyph: root.media.playing ? "\uf04c" : "\uf04b"; primary: true; enabled: root.media.canToggle; Accessible.name: root.media.playing ? "Pause" : "Play"; onClicked: root.media.toggle() }
      Transport { objectName: "lockNext"; glyph: "\uf051"; enabled: root.media.canNext; Accessible.name: "Next"; onClicked: root.media.next() }
    }
  }
}
