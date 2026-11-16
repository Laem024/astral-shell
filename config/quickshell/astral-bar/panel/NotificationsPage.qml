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
    Rectangle {
      Layout.fillWidth: true
      implicitHeight: dndRow.implicitHeight + 28
      radius: 8
      color: root.service.dnd ? Qt.alpha(root.tokens.cyan, 0.07) : root.tokens.background
      border.color: root.service.dnd ? Qt.alpha(root.tokens.cyan, 0.35) : root.tokens.border
      RowLayout {
        id: dndRow
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 12
        ColumnLayout {
          Layout.fillWidth: true; spacing: 5
          Text {
            Layout.fillWidth: true
            text: "Do not disturb"; color: root.tokens.text
            font { family: root.tokens.font; pixelSize: 13; weight: Font.DemiBold }
          }
          Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: root.service.dnd ? "Enabled · Silent notifications" : "Disabled · Alerts allowed"
            color: root.service.dnd ? root.tokens.cyan : root.tokens.muted
            font { family: root.tokens.font; pixelSize: 11 }
          }
          Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap
            text: "Notifications stay in your history."
            color: root.tokens.muted
            font { family: root.tokens.font; pixelSize: 10 }
          }
        }
        Switch {
          id: quietToggle
          objectName: "notificationDndToggle"
          implicitWidth: 44; implicitHeight: 32
          checked: root.service.dnd
          onToggled: root.service.dnd = checked
          focusPolicy: Qt.StrongFocus
          Accessible.name: "Do not disturb"
          Accessible.description: checked ? "Enabled. Popups and system notification sounds are muted. App audio is unchanged." : "Disabled. Notification alerts are allowed."
          leftPadding: 2; rightPadding: 2; topPadding: 4; bottomPadding: 4
          indicator: Rectangle {
            implicitWidth: 40; implicitHeight: 24
            x: quietToggle.leftPadding
            y: (quietToggle.height - height) / 2
            radius: 12
            color: quietToggle.checked ? root.tokens.cyan : Qt.alpha(root.tokens.muted, 0.15)
            border.color: quietToggle.activeFocus ? root.tokens.cyan : root.tokens.border
            border.width: quietToggle.activeFocus ? 2 : 1
            Rectangle {
              x: quietToggle.checked ? 19 : 3; y: 3
              width: 18; height: 18; radius: 9
              color: quietToggle.checked ? root.tokens.background : root.tokens.muted
              Behavior on x { NumberAnimation { duration: root.tokens.hoverDuration } }
            }
          }
          contentItem: Item { implicitWidth: 0; implicitHeight: 24 }
        }
      }
    }
    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 4
      spacing: 8
      Text {
        Layout.fillWidth: true
        objectName: "notificationHistoryCount"
        text: root.service.entries.length + (root.service.entries.length === 1 ? " notification" : " notifications")
        color: root.tokens.muted
        font { family: root.tokens.mono; pixelSize: 11 }
      }
      PanelButton {
        tokens: root.tokens; text: "Clear all"; implicitHeight: 28
        enabled: root.service.entries.length > 0
        onClicked: root.service.clear()
      }
    }
    ScrollView {
      id: history
      Layout.fillWidth: true; Layout.fillHeight: true
      contentWidth: availableWidth; clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ColumnLayout {
        width: history.availableWidth; spacing: 8
        Item {
          visible: root.service.entries.length === 0
          Layout.fillWidth: true
          implicitHeight: Math.max(120, history.availableHeight)
          ColumnLayout {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 24)
            spacing: 8
            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "All caught up"; color: root.tokens.text
              font { family: root.tokens.font; pixelSize: 18; weight: Font.Medium }
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
