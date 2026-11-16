pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../data" as Data
import "../design" as Design
import "../components" as Components

Rectangle {
  id: root
  required property var entry
  required property Design.Theme tokens
  property var service: Data.NotificationData
  property bool popup: false
  readonly property bool canOpen: service.canOpen(entry)
  readonly property bool fileNotice: !!entry.file
  readonly property bool video: fileNotice && /\.(mkv|mp4|webm|avi|mov|m4v)$/i.test(entry.file)
  readonly property color accent: entry.urgency === 2 ? tokens.alert : tokens.cyan
  readonly property var actions: entry.actions.filter(action => action.id !== "default")
  readonly property int inset: popup ? 16 : 14
  objectName: "notificationCard"
  implicitHeight: content.implicitHeight + inset * 2
  Layout.fillWidth: true
  Layout.minimumHeight: implicitHeight
  radius: popup ? 12 : 8
  color: popup ? tokens.surface : tokens.background
  border.color: entry.urgency === 2 ? Qt.alpha(tokens.alert, 0.5) : tokens.border
  Rectangle {
    x: root.popup ? 16 : 0
    y: root.popup ? 0 : 16
    width: root.popup ? 32 : 2
    height: root.popup ? 2 : Math.max(0, parent.height - 32)
    radius: 1
    visible: root.entry.urgency === 2 || !root.entry.read
    color: root.accent
  }
  HoverHandler { onHoveredChanged: if (root.popup) root.service.pause(root.entry.id, hovered) }
  Component.onDestruction: if (popup) service.pause(entry.id, false)
  component Action: PanelButton {
    id: action
    tokens: root.tokens
    implicitHeight: 32
    focusPolicy: root.popup ? Qt.NoFocus : Qt.StrongFocus
    background: Rectangle {
      radius: 7
      color: Qt.alpha(root.accent, action.selected ? 0.12 : action.hovered ? 0.06 : 0)
      border.color: action.visualFocus ? root.accent : action.selected ? Qt.alpha(root.accent, 0.3) : root.tokens.border
    }
  }
  ColumnLayout {
    id: content
    anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.inset }
    spacing: root.popup ? 12 : 10
    RowLayout {
      Layout.fillWidth: true
      spacing: 9
      Rectangle {
        Layout.preferredWidth: 30; Layout.preferredHeight: 30
        radius: 8
        color: Qt.alpha(root.accent, 0.08)
        Components.CaptureGlyph {
          anchors.centerIn: parent
          visible: root.fileNotice
          kind: root.video ? "window" : "capture"
          ink: root.accent
          scale: 0.75
        }
        Image {
          id: icon
          anchors.fill: parent; anchors.margins: 5
          visible: !root.fileNotice
          source: root.entry.icon ? Quickshell.iconPath(root.entry.icon, true) : ""
          sourceSize.width: 40; sourceSize.height: 40
          fillMode: Image.PreserveAspectFit
        }
        Text {
          anchors.centerIn: parent
          visible: !root.fileNotice && icon.status !== Image.Ready
          text: root.entry.app.charAt(0).toUpperCase(); textFormat: Text.PlainText
          color: root.accent
          font { family: root.tokens.font; pixelSize: 14; weight: Font.Medium }
        }
      }
      Text {
        Layout.fillWidth: true; Layout.minimumWidth: 0
        text: root.entry.app; textFormat: Text.PlainText
        elide: Text.ElideRight; color: root.tokens.muted
        font { family: root.tokens.font; pixelSize: 11 }
      }
      Text {
        visible: root.fileNotice && root.popup
        text: root.video ? "VIDEO" : "PNG"
        color: root.accent
        font { family: root.tokens.mono; pixelSize: 8; letterSpacing: 0.8 }
      }
      Text {
        text: Qt.formatTime(root.entry.time, "hh:mm")
        color: root.tokens.muted
        font { family: root.tokens.mono; pixelSize: 9 }
      }
      ToolButton {
        id: dismiss
        Layout.preferredWidth: 24; Layout.preferredHeight: 24
        focusPolicy: root.popup ? Qt.NoFocus : Qt.StrongFocus
        Accessible.name: root.popup ? "Hide notification" : "Delete notification"
        contentItem: Text {
          text: "×"; color: dismiss.hovered ? root.tokens.text : root.tokens.muted
          horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
          font { family: root.tokens.font; pixelSize: 17 }
        }
        background: Rectangle {
          radius: 6
          color: dismiss.hovered ? Qt.alpha(root.tokens.muted, 0.1) : "transparent"
          border.color: dismiss.visualFocus ? root.accent : "transparent"
        }
        onClicked: root.popup ? root.service.hide(root.entry.id) : root.service.remove(root.entry.id)
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6
      TapHandler { enabled: root.canOpen; onTapped: root.service.open(root.entry.id) }
      Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.entry.summary; textFormat: Text.PlainText
        color: root.tokens.text; wrapMode: Text.Wrap
        maximumLineCount: root.popup ? 2 : 100; elide: Text.ElideRight
        font { family: root.tokens.font; pixelSize: root.popup ? 16 : 15; weight: Font.Medium }
      }
      Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.fileNotice && root.popup ? root.entry.file.split("/").pop() : root.entry.body
        textFormat: Text.PlainText
        color: root.tokens.muted; wrapMode: Text.Wrap
        maximumLineCount: root.popup ? (root.fileNotice ? 2 : 4) : 100; elide: Text.ElideRight
        font { family: root.fileNotice ? root.tokens.mono : root.tokens.font; pixelSize: root.fileNotice && root.popup ? 10 : 12 }
      }
    }
    Text {
      visible: root.entry.urgency === 2
      text: "Critical"; color: root.tokens.alert
      font { family: root.tokens.mono; pixelSize: 10 }
    }
    Text {
      objectName: "fileLaunchFeedback"
      Layout.fillWidth: true
      visible: !!root.entry.launchMessage
      text: root.entry.launchMessage || ""
      textFormat: Text.PlainText; wrapMode: Text.Wrap
      color: root.entry.launchState === "error" ? root.tokens.alert : root.tokens.cyan
      font { family: root.tokens.font; pixelSize: 11 }
      Accessible.role: Accessible.StaticText
    }
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 1
      visible: root.popup && (root.canOpen || root.actions.length > 0)
      color: root.tokens.border
    }
    Flow {
      id: actions
      Layout.fillWidth: true
      visible: root.canOpen || root.actions.length > 0
      spacing: 8
      Action {
        visible: root.canOpen
        text: root.entry.launchState === "opening" ? "Opening…" : root.entry.launchState === "error" ? "Try again" : root.fileNotice ? root.video ? "Play video" : "View image" : "Open"
        selected: true
        enabled: root.entry.launchState !== "opening"
        width: Math.min(implicitWidth, actions.width)
        onClicked: root.service.open(root.entry.id)
      }
      Repeater {
        model: root.actions
        Action {
          required property var modelData
          text: root.fileNotice && modelData.id === "folder" ? "Show folder" : modelData.text
          enabled: root.entry.launchState !== "opening"
          width: Math.min(implicitWidth, actions.width)
          onClicked: root.service.invoke(root.entry.id, modelData.id)
        }
      }
    }
  }
}
