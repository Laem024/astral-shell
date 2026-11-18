pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell.Io
import QtQuick.Layouts
import "../../common" as Design
import "../data" as Data

Item {
  id: root
  required property Design.Theme tokens
  required property var settings
  property string tab: "Control Center"
  property string monitorName: ""
  signal tabSelected(string name)
  signal captureRequested()
  readonly property bool compact: width < 620
  readonly property bool shortPanel: height < 590
  property string pickerMode: ""
  Component.onCompleted: Data.UserData.refresh()
  readonly property var categories: [
    {key: "Weather & Calendar", title: "Calendar", symbol: "calendar", accent: tokens.gold},
    {key: "Media", title: "Music", symbol: "music", accent: tokens.lavender},
    {key: "Control Center", title: "Connections", symbol: "connections", accent: tokens.cyan},
    {key: "Display", title: "Screen & captures", symbol: "screen", accent: tokens.lavender},
    {key: "Sound", title: "Sound", symbol: "sound", accent: tokens.cyan},
    {key: "Power", title: "Energy & session", symbol: "bolt", accent: tokens.gold},
    {key: "Notifications", title: "Notifications", symbol: "notifications", accent: tokens.lavender}
  ]
  ColumnLayout {
    anchors.fill: parent
    visible: root.pickerMode === ""
    spacing: 16
    ProfileHeader {
      id: profileHeader
      Layout.fillWidth: true
      Layout.preferredHeight: implicitHeight
      tokens: root.tokens
      compact: root.shortPanel
      onEditRequested: mode => root.pickerMode = mode
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
      Layout.minimumHeight: 0
      spacing: 16
      Rectangle {
        objectName: "panelCategories"
        Layout.preferredWidth: root.compact ? 52 : 174
        Layout.fillHeight: true
        radius: root.tokens.cardRadius
        color: root.tokens.background
        border.color: root.tokens.hairline
        ColumnLayout {
          anchors { fill: parent; margins: 6 }
          spacing: 5
          Text {
            visible: !root.compact && !root.shortPanel
            Layout.fillWidth: true
            Layout.margins: 10
            text: "CATEGORIES"
            color: root.tokens.muted
            font { family: root.tokens.mono; pixelSize: 8; letterSpacing: 1.4 }
          }
          Repeater {
            model: root.categories
            PanelButton {
              id: categoryButton
              required property var modelData
              objectName: "panelCategory-" + modelData.key
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.minimumHeight: 0
              Layout.maximumHeight: 48
              tokens: root.tokens
              text: modelData.title
              selected: root.tab === modelData.key
              tint: modelData.accent
              leftPadding: root.compact ? 8 : 12
              rightPadding: root.compact ? 8 : 10
              Accessible.role: Accessible.RadioButton
              Accessible.checkable: true
              Accessible.checked: selected
              contentItem: RowLayout {
                spacing: 10
                CategoryGlyph {
                  Layout.preferredWidth: 20; Layout.preferredHeight: 24
                  kind: categoryButton.modelData.symbol
                  ink: categoryButton.selected ? categoryButton.tint : root.tokens.muted
                  scale: 0.8
                }
                Text {
                  visible: !root.compact
                  Layout.fillWidth: true
                  text: categoryButton.text
                  color: categoryButton.selected ? root.tokens.text : root.tokens.muted
                  font { family: root.tokens.font; pixelSize: 11; weight: categoryButton.selected ? Font.DemiBold : Font.Medium }
                  verticalAlignment: Text.AlignVCenter
                  elide: Text.ElideRight
                }
              }
              onClicked: root.tabSelected(modelData.key)
            }
          }
          Item { Layout.fillHeight: true; Layout.minimumHeight: 0 }
          RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
              visible: !root.compact
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              Layout.leftMargin: 10
              text: "ASTRAL SHELL"
              elide: Text.ElideRight
              color: root.tokens.muted
              font { family: root.tokens.mono; pixelSize: 8; letterSpacing: 1.4 }
            }
            PanelButton {
              id: settingsButton
              objectName: "astralSettingsButton"
              Layout.minimumWidth: 38
              Layout.preferredWidth: 38
              Layout.maximumWidth: 38
              Layout.minimumHeight: 38
              Layout.preferredHeight: 38
              Layout.maximumHeight: 38
              Layout.alignment: Qt.AlignHCenter
              tokens: root.tokens
              text: "Settings"
              leftPadding: 0
              rightPadding: 0
              topPadding: 0
              bottomPadding: 0
              contentItem: Item {
                CategoryGlyph {
                  objectName: "astralSettingsGlyph"
                  anchors.centerIn: parent
                  width: 24; height: 24
                  scale: 0.85
                  kind: "sliders"
                  ink: settingsButton.hovered || settingsButton.activeFocus ? root.tokens.cyan : root.tokens.muted
                }
              }
              onClicked: settingsCommand.run(["astral-settings", "open"], () => {})
            }
          }
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
        Layout.minimumHeight: 0
        spacing: 12
        Loader {
          id: pageLoader
          objectName: "centralPageLoader"
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumWidth: 0
          Layout.minimumHeight: 0
          sourceComponent: root.tab === "Weather & Calendar" ? weatherPage : root.tab === "Media" ? mediaPage : root.tab === "Display" ? displayPage : root.tab === "Sound" ? soundPage : root.tab === "Power" ? powerPage : root.tab === "Notifications" ? noticesPage : controlPage
          onLoaded: pageEntrance.restart()
        }
      }
    }
  }
  Design.Command { id: settingsCommand }
  NumberAnimation { id: pageEntrance; target: pageLoader; property: "opacity"; from: 0; to: 1; duration: root.tokens.entryDuration; easing.type: Easing.OutCubic }
  Loader {
    anchors.fill: parent
    active: root.pickerMode !== ""
    focus: true
    sourceComponent: AvatarPicker {
      tokens: root.tokens
      mode: root.pickerMode
      bannerAspect: root.width / profileHeader.implicitHeight
      onClosed: root.pickerMode = ""
    }
  }
  Component { id: weatherPage; WeatherPage { tokens: root.tokens; settings: root.settings } }
  Component { id: mediaPage; MediaPage { tokens: root.tokens } }
  Component { id: noticesPage; NotificationsPage { tokens: root.tokens } }
  Component { id: displayPage; DisplayPage { tokens: root.tokens; monitorName: root.monitorName; onCaptureRequested: root.captureRequested() } }
  Component { id: soundPage; SoundPage { tokens: root.tokens } }
  Component { id: controlPage; ControlPage { tokens: root.tokens } }
  Component { id: powerPage; PowerPage { tokens: root.tokens } }
}
