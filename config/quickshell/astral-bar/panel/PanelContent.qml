pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Design
import "../data" as Data
import "../components" as Components

Item {
  id: root
  required property Design.Theme tokens
  required property var settings
  property string tab: "Control Center"
  signal tabSelected(string name)
  signal captureRequested()
  readonly property bool compact: width < 500
  property string pickerMode: ""
  Component.onCompleted: Data.UserData.refresh()
  readonly property string profileName: Data.UserData.displayName
  readonly property string initials: profileName.split(/\s+/).slice(0, 2).map(word => word[0]).join("").toUpperCase()
  readonly property var categories: [
    {key: "Weather & Calendar", title: "Calendar & weather", shortName: "CAL", hint: "Your day at a glance"},
    {key: "Media", title: "Music", shortName: "MUS", hint: "Now playing"},
    {key: "Control Center", title: "Connections & controls", shortName: "NET", hint: "Network & devices"},
    {key: "Display", title: "Screen & capture", shortName: "CAP", hint: "Displays, screenshots & recording"},
    {key: "Sound", title: "Sound", shortName: "VOL", hint: "Output, microphone & applications"},
    {key: "Power", title: "Power & session", shortName: "PWR", hint: "Battery & session"},
    {key: "Notifications", title: "Notifications", shortName: "LOG", hint: "Your recent activity"}
  ]
  readonly property var current: categories.find(category => category.key === tab) || categories[2]
  ColumnLayout {
    anchors.fill: parent
    visible: root.pickerMode === ""
    spacing: 16
    Rectangle {
      id: header
      Layout.fillWidth: true
      implicitHeight: 160
      Layout.minimumHeight: 160
      radius: root.tokens.cardRadius
      color: root.tokens.background
      border.color: root.tokens.border
      Components.RoundedClip {
        anchors.fill: parent
        radius: root.tokens.cardRadius
        Components.CropImage {
          id: bannerImage
          anchors.fill: parent
          source: Data.BannerData.source
          zoom: Data.BannerData.zoom
          focusX: Data.BannerData.focusX
          focusY: Data.BannerData.focusY
        }
      }
      Item {
        id: bannerControl
        anchors.fill: parent
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: Data.BannerData.file ? "Change or remove banner" : "Add banner"
        Accessible.onPressAction: root.pickerMode = "banner"
        Keys.onReturnPressed: root.pickerMode = "banner"
        Keys.onEnterPressed: root.pickerMode = "banner"
        Keys.onSpacePressed: root.pickerMode = "banner"
        Rectangle {
          anchors.fill: parent
          radius: root.tokens.cardRadius; color: "transparent"
          border.width: bannerControl.activeFocus ? 2 : 0
          border.color: root.tokens.cyan
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { bannerControl.forceActiveFocus(); root.pickerMode = "banner"; }
        }
      }
      // A solid ornamental cartouche joins the portrait to both account labels.
      Rectangle {
        x: accountRow.x + accountRow.height / 2
        y: accountRow.y + (accountRow.height - height) / 2
        width: accountRow.width - accountRow.height / 2 - 36 - accountRow.spacing
        height: 72
        radius: height / 2
        color: root.tokens.background
        border.color: root.tokens.cyan
        Rectangle {
          anchors.fill: parent
          anchors.margins: 5
          radius: height / 2
          color: "transparent"
          border.color: Qt.alpha(root.tokens.cyan, 0.3)
        }
        Rectangle {
          anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 13 }
          width: 7; height: 7
          rotation: 45
          color: root.tokens.cyan
        }
      }
      RowLayout {
        id: accountRow
        objectName: "panelAccount"
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.margins: root.tokens.inset
        height: 88
        spacing: root.compact ? 12 : 16
        PanelButton {
          tokens: root.tokens
          Layout.preferredWidth: 88; Layout.preferredHeight: 88
          leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
          text: "Change account photo"
          onClicked: root.pickerMode = "avatar"
          background: Rectangle { radius: 44; color: root.tokens.background }
          contentItem: Item {
            Components.RoundedClip {
              anchors.fill: parent
              radius: 44
              Image {
                id: avatar
                anchors.fill: parent
                source: Data.UserData.avatar
                cache: false
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
              }
            }
            Rectangle {
              anchors.fill: parent
              radius: 44; color: "transparent"
              border.width: parent.parent.activeFocus ? 3 : 2
              border.color: root.tokens.cyan
            }
            Text {
              anchors.centerIn: parent
              visible: avatar.status !== Image.Ready
              text: root.initials
              color: root.tokens.cyan
              font { family: root.tokens.mono; pixelSize: 28; weight: Font.Medium }
            }
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          Layout.rightMargin: 26
          spacing: 4
          Text {
            Layout.fillWidth: true
            text: root.profileName
            textFormat: Text.PlainText
            color: root.tokens.text
            elide: Text.ElideRight
            Accessible.name: root.profileName
            font { family: root.tokens.font; pixelSize: 18; weight: Font.Medium }
          }
          Text {
            Layout.fillWidth: true
            text: "@" + Data.UserData.username
            textFormat: Text.PlainText
            color: root.tokens.muted
            elide: Text.ElideRight
            font { family: root.tokens.font; pixelSize: 11 }
          }
        }
        Item {
          Layout.preferredWidth: 36
          Layout.preferredHeight: 36
          // Keep the inactive settings control from opening the banner beneath it.
          MouseArea { anchors.fill: parent }
          PanelButton {
            anchors.fill: parent
            tokens: root.tokens
            text: "Settings"
            Accessible.name: "Settings (coming soon)"
            preview: true
            leftPadding: 0; rightPadding: 0
            contentItem: Item {
              Item {
                anchors.centerIn: parent
                width: 20; height: 20
                Repeater {
                  model: 8
                  Item {
                    required property int index
                    anchors.fill: parent
                    rotation: index * 45
                    Rectangle { x: 8; y: 0; width: 4; height: 5; radius: 1; color: root.tokens.muted }
                  }
                }
                Rectangle {
                  anchors.centerIn: parent
                  width: 14; height: 14; radius: 7
                  color: root.tokens.muted
                  Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: root.tokens.background }
                }
              }
            }
          }
        }
      }
    }
    Text {
      Layout.fillWidth: true
      visible: text !== ""
      text: Data.UserData.error || Data.BannerData.error
      color: root.tokens.alert
      wrapMode: Text.Wrap
      font { family: root.tokens.font; pixelSize: 11 }
    }
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 16
      Rectangle {
        objectName: "panelCategories"
        Layout.preferredWidth: root.compact ? 52 : 148
        Layout.fillHeight: true
        radius: root.tokens.cardRadius
        color: "transparent"
        Rectangle {
          anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
          width: 1
          color: root.tokens.hairline
        }
        ColumnLayout {
          anchors { fill: parent; margins: 6 }
          spacing: 2
          Repeater {
            model: root.categories
            PanelButton {
              id: categoryButton
              required property var modelData
              objectName: "panelCategory-" + modelData.key
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: 0
              Layout.maximumHeight: 44
              tokens: root.tokens
              text: root.compact ? modelData.shortName : ({ "Weather & Calendar": "Calendar", "Media": "Music", "Display": "Screen & capture", "Sound": "Sound", "Control Center": "Connections", "Power": "Power & session", "Notifications": "Notifications" })[modelData.key]
              Accessible.name: modelData.title
              selected: root.tab === modelData.key
              leftPadding: root.compact ? 0 : 12
              rightPadding: root.compact ? 0 : 12
              implicitHeight: 40
              contentItem: Text {
                text: categoryButton.text
                color: categoryButton.selected ? root.tokens.cyan : categoryButton.hovered ? root.tokens.text : root.tokens.muted
                font { family: root.tokens.font; pixelSize: root.compact ? 10 : 12; weight: categoryButton.selected ? Font.DemiBold : Font.Normal }
                horizontalAlignment: root.compact ? Text.AlignHCenter : Text.AlignLeft
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
              }
              background: Rectangle {
                color: categoryButton.down ? Qt.alpha(root.tokens.cyan, 0.12) : categoryButton.hovered ? Qt.alpha(root.tokens.cyan, 0.06) : "transparent"
                radius: root.tokens.rowRadius
                border.width: categoryButton.visualFocus ? 1 : 0
                border.color: root.tokens.cyan
                Rectangle {
                  anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                  width: 2
                  height: parent.height * 0.5
                  radius: 1
                  color: root.tokens.cyan
                  visible: categoryButton.selected
                }
              }
              onClicked: root.tabSelected(modelData.key)
            }
          }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
        spacing: 12
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          Text {
            Layout.fillWidth: true
            text: root.current.title
            color: root.tokens.text
            elide: Text.ElideRight
            font { family: root.tokens.font; pixelSize: 18; weight: Font.Medium }
          }
          Text {
            Layout.fillWidth: true
            text: root.current.hint
            color: root.tokens.muted
            elide: Text.ElideRight
            font { family: root.tokens.font; pixelSize: 11 }
          }
        }
        Loader {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumWidth: 0
          sourceComponent: root.tab === "Weather & Calendar" ? weatherPage : root.tab === "Media" ? mediaPage : root.tab === "Display" ? displayPage : root.tab === "Sound" ? soundPage : root.tab === "Power" ? powerPage : root.tab === "Notifications" ? noticesPage : controlPage
        }
      }
    }
  }
  Loader {
    anchors.fill: parent
    active: root.pickerMode !== ""
    focus: true
    sourceComponent: AvatarPicker {
      tokens: root.tokens
      mode: root.pickerMode
      bannerAspect: root.width / 160
      onClosed: root.pickerMode = ""
    }
  }
  Component { id: weatherPage; WeatherPage { tokens: root.tokens; settings: root.settings } }
  Component { id: mediaPage; MediaPage { tokens: root.tokens } }
  Component { id: noticesPage; NotificationsPage { tokens: root.tokens } }
  Component { id: displayPage; DisplayPage { tokens: root.tokens; onCaptureRequested: root.captureRequested() } }
  Component { id: soundPage; SoundPage { tokens: root.tokens } }
  Component { id: controlPage; ControlPage { tokens: root.tokens } }
  Component { id: powerPage; PowerPage { tokens: root.tokens } }
}
