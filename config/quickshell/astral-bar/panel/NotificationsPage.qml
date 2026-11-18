pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Design
import "../data" as Data

Item {
  id: root
  required property Design.Theme tokens
  property var service: Data.NotificationData
  property bool registered: false
  function syncReader(): void {
    if (visible === registered) return;
    service.readers += visible ? 1 : -1;
    registered = visible;
  }
  Component.onCompleted: syncReader()
  onVisibleChanged: syncReader()
  Component.onDestruction: if (registered) service.readers--
  ColumnLayout {
    anchors.fill: parent
    spacing: 12
    PageIntro {
      tokens: root.tokens
      title: "A moment of clarity"
      subtitle: root.service.entries.length + " notifications in your history"
      symbol: "notifications"
      accent: root.tokens.lavender
    }
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: dndRow.implicitHeight + root.tokens.inset * 2
      radius: root.tokens.cardRadius
      color: root.service.dnd ? Qt.alpha(root.tokens.lavender, 0.1) : root.tokens.background
      border.color: root.service.dnd ? Qt.alpha(root.tokens.lavender, 0.35) : root.tokens.border
      RowLayout {
        id: dndRow
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.tokens.inset }
        spacing: 12
        Rectangle {
          Layout.preferredWidth: 40; Layout.preferredHeight: 40
          radius: 14
          color: Qt.alpha(root.tokens.lavender, 0.12)
          CategoryGlyph { anchors.centerIn: parent; kind: "notifications"; ink: root.tokens.lavender; width: 24; height: 24 }
        }
        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: 4
          Text {
            Layout.fillWidth: true
            text: "Do not disturb"; color: root.tokens.text
            font { family: root.tokens.font; pixelSize: 14; weight: Font.Medium }
          }
          Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: root.service.dnd ? "Enabled · Silent notifications" : "Disabled · Alerts allowed"
            color: root.service.dnd ? root.tokens.lavender : root.tokens.muted
            font { family: root.tokens.font; pixelSize: 12 }
          }
          Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: "Notifications stay in your history."
            color: root.tokens.muted
            font { family: root.tokens.font; pixelSize: 11 }
          }
        }
        PanelSwitch {
          id: quietToggle
          objectName: "notificationDndToggle"
          tokens: root.tokens
          accent: root.tokens.lavender
          checked: root.service.dnd
          onToggled: root.service.dnd = checked
          Accessible.name: "Do not disturb"
          Accessible.description: checked ? "Enabled. Popups and system notification sounds are muted. App audio is unchanged." : "Disabled. Notification alerts are allowed."
        }
      }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Text {
        Layout.fillWidth: true
        objectName: "notificationHistoryCount"
        text: root.service.entries.length + (root.service.entries.length === 1 ? " notification" : " notifications")
        color: root.tokens.muted
        elide: Text.ElideRight
        font { family: root.tokens.mono; pixelSize: 11 }
      }
      PanelButton {
        tokens: root.tokens; text: "Clear all"; implicitHeight: 32
        enabled: root.service.entries.length > 0
        onClicked: root.service.clear()
      }
    }
    ScrollView {
      id: history
      Layout.fillWidth: true; Layout.fillHeight: true
      Layout.minimumWidth: 0
      contentWidth: availableWidth; clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ColumnLayout {
        width: history.availableWidth; spacing: 8
        Item {
          visible: root.service.entries.length === 0
          Layout.fillWidth: true
          implicitHeight: Math.max(140, history.availableHeight)
          ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 32)
            spacing: 12
            Rectangle {
              Layout.alignment: Qt.AlignHCenter
              Layout.preferredWidth: 64; Layout.preferredHeight: 64
              radius: 24
              color: Qt.alpha(root.tokens.lavender, 0.08)
              CategoryGlyph { anchors.centerIn: parent; kind: "check"; ink: root.tokens.lavender; width: 24; height: 24 }
            }
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "All caught up"; color: root.tokens.text
              font { family: root.tokens.font; pixelSize: 16; weight: Font.Medium }
            }
            Text {
              Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
              text: "New notifications will appear here."; wrapMode: Text.Wrap
              color: root.tokens.muted
              font { family: root.tokens.font; pixelSize: 12 }
            }
          }
        }
        Repeater {
          model: root.service.entries
          NotificationCard {
            required property var modelData
            tokens: root.tokens; service: root.service; entry: modelData
          }
        }
      }
    }
  }
}
