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
      implicitHeight: 112
      Layout.minimumHeight: 112
      radius: 8
      color: root.tokens.background
      border.color: root.tokens.border
      readonly property bool hasBanner: bannerImage.status === Image.Ready
      Components.RoundedClip {
        anchors.fill: parent
        radius: 8
        Components.CropImage {
          id: bannerImage
          anchors.fill: parent
          source: Data.BannerData.source
          zoom: Data.BannerData.zoom
          focusX: Data.BannerData.focusX
          focusY: Data.BannerData.focusY
        }
        Rectangle {
          anchors.fill: parent
          visible: header.hasBanner
          color: "#99000000"
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
          radius: 8; color: "transparent"
          border.color: bannerControl.activeFocus ? root.tokens.cyan : "transparent"
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { bannerControl.forceActiveFocus(); root.pickerMode = "banner"; }
        }
      }
      RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: root.compact ? 12 : 16
        PanelButton {
          tokens: root.tokens
          Layout.preferredWidth: 80; Layout.preferredHeight: 80
          leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
          text: "Change account photo"
          onClicked: root.pickerMode = "avatar"
          contentItem: Item {
            Components.RoundedClip {
              anchors.fill: parent
              radius: 8
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
              radius: 8; color: "transparent"
              border.color: parent.parent.activeFocus ? root.tokens.cyan : root.tokens.border
            }
            Text {
              anchors.centerIn: parent
              visible: avatar.status !== Image.Ready
              text: root.initials
              color: header.hasBanner ? "#FFFFFF" : root.tokens.cyan
              font { family: root.tokens.mono; pixelSize: 22; weight: Font.Medium }
            }
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: 4
          Text {
            Layout.fillWidth: true
            text: root.profileName
            textFormat: Text.PlainText
            color: header.hasBanner ? "#FFFFFF" : root.tokens.text
            style: header.hasBanner ? Text.Outline : Text.Normal
            styleColor: "#CC000000"
            elide: Text.ElideRight
            Accessible.name: root.profileName
            font { family: root.tokens.font; pixelSize: 22; weight: Font.Medium }
          }
          Text {
            Layout.fillWidth: true
            text: "@" + Data.UserData.username
            textFormat: Text.PlainText
            color: header.hasBanner ? "#EEEEEE" : root.tokens.muted
            style: header.hasBanner ? Text.Outline : Text.Normal
            styleColor: "#CC000000"
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
    }
    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: 16
      ScrollView {
        Layout.preferredWidth: root.compact ? 46 : 142
        Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ColumnLayout {
          width: parent.width
          spacing: 8
          Repeater {
            model: root.categories
            PanelButton {
              required property var modelData
              Layout.fillWidth: true
              tokens: root.tokens
              text: root.compact ? modelData.shortName : ({ "Weather & Calendar": "Calendar", "Media": "Music", "Display": "Screen & capture", "Sound": "Sound", "Control Center": "Connections", "Power": "Power & session", "Notifications": "Notifications" })[modelData.key]
              Accessible.name: modelData.title
              selected: root.tab === modelData.key
              onClicked: root.tabSelected(modelData.key)

            }
          }
        }
      }
      Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: root.tokens.border }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 12
        Text { Layout.fillWidth: true; text: root.current.title; color: root.tokens.text; wrapMode: Text.Wrap; font { family: root.tokens.font; pixelSize: 22 } }
        Text { Layout.fillWidth: true; text: root.current.hint; color: root.tokens.muted; wrapMode: Text.Wrap; font { family: root.tokens.font; pixelSize: 11 } }
        Loader {
          Layout.fillWidth: true
          Layout.fillHeight: true
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
      bannerAspect: root.width / 112
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
