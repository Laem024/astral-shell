pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "../data" as Data
import "../design" as Design

ScrollView {
  id: root
  required property Design.Theme tokens
  readonly property var power: Data.PowerData.state
  readonly property bool compact: availableWidth < 320
  readonly property bool batteryAvailable: Data.SystemData.batteryAvailable
  readonly property real batteryLevel: batteryAvailable ? Math.max(0, Math.min(100, Data.SystemData.batteryPercent)) / 100 : 0
  readonly property color batteryAccent: batteryAvailable && batteryLevel <= 0.2 && !Data.SystemData.externalPower ? tokens.alert : tokens.cyan
  readonly property string profileLabel: ({"power-saver": "Power saver", balanced: "Balanced", performance: "Performance"})[power.profile] || "Unavailable"
  contentWidth: availableWidth
  clip: true
  // Keep curve-rendered icons inside the scrolling viewport.
  layer.enabled: true
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
  onVisibleChanged: if (!visible) Data.SessionData.cancel()
  Component.onDestruction: Data.SessionData.cancel()
  Keys.onEscapePressed: event => {
    if (Data.SessionData.confirmation !== "") { Data.SessionData.cancel(); event.accepted = true; }
    else event.accepted = false;
  }

  component Caption: Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    color: root.tokens.muted
    font { family: root.tokens.font; pixelSize: 11 }
  }
  component Eyebrow: Caption {
    color: root.tokens.cyan
    font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 1.3 }
  }
  component Diagnostic: Caption {
    visible: text !== ""
    color: root.tokens.alert
    Accessible.role: Accessible.StaticText
  }
  component Section: PanelCard {
    tokens: root.tokens
    radius: 12
    contentSpacing: 12
  }
  component ProfileIcon: Shape {
    id: profileIcon
    required property string profileName
    required property color ink
    preferredRendererType: Shape.CurveRenderer
    Accessible.ignored: true
    ShapePath {
      strokeColor: profileIcon.ink
      strokeWidth: 1.6
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      fillColor: "transparent"
      PathSvg {
        path: profileIcon.profileName === "power-saver"
          ? "M5 19 C2 13 5 5 20 4 C20 18 13 22 7 17 M4 21 L15 10 M9 16 L9 12 M12 13 L16 13"
          : profileIcon.profileName === "balanced"
          ? "M3 7 H7 M13 7 H21 M3 17 H13 M19 17 H21 M13 7 A3 3 0 1 1 7 7 A3 3 0 1 1 13 7 M19 17 A3 3 0 1 1 13 17 A3 3 0 1 1 19 17"
          : "M13 2 L4 14 H11 L10 22 L20 9 H13 Z"
      }
    }
  }
  component Action: PanelButton {
    id: action
    property string symbol: ""
    readonly property color accent: destructive ? root.tokens.alert : root.tokens.cyan
    tokens: root.tokens
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: 38
    opacity: enabled ? 1 : 0.4
    contentItem: RowLayout {
      spacing: 8
      Text {
        visible: action.symbol !== ""
        text: action.symbol
        color: action.accent
        font { family: root.tokens.mono; pixelSize: 15 }
      }
      Text {
        Layout.fillWidth: true
        text: action.text
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: action.destructive || action.selected ? action.accent : root.tokens.text
        font { family: root.tokens.font; pixelSize: 11; weight: Font.Medium }
        verticalAlignment: Text.AlignVCenter
      }
    }
    background: Rectangle {
      radius: 8
      color: Qt.alpha(action.accent, action.down ? 0.16 : action.selected ? 0.1 : action.hovered ? 0.07 : 0.025)
      border.color: action.visualFocus ? root.tokens.gold : Qt.alpha(action.accent, action.selected ? 0.4 : action.hovered ? 0.3 : 0.13)
      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
    }
  }

  ColumnLayout {
    width: root.availableWidth
    spacing: 12
    Section {
      objectName: "powerBatteryCard"
      border.color: Qt.alpha(root.batteryAccent, 0.22)
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.tint(root.tokens.background, Qt.alpha(root.batteryAccent, 0.07)) }
        GradientStop { position: 1; color: root.tokens.background }
      }
      RowLayout {
        Layout.fillWidth: true
        Eyebrow { text: "POWER"; color: root.batteryAccent }
        Rectangle {
          implicitWidth: sourceLabel.implicitWidth + 16
          implicitHeight: 24
          radius: 12
          color: Qt.alpha(root.batteryAccent, 0.08)
          Text {
            id: sourceLabel
            anchors.centerIn: parent
            text: Data.SystemData.externalPower ? "PLUGGED IN" : root.batteryAvailable ? "BATTERY" : "NO DATA"
            color: root.batteryAccent
            font { family: root.tokens.mono; pixelSize: 8; letterSpacing: 0.8 }
          }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 16
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2
          RowLayout {
            spacing: 4
            Text {
              text: root.batteryAvailable ? Data.SystemData.batteryPercent : "—"
              color: root.tokens.text
              font { family: root.tokens.font; pixelSize: 48; weight: Font.Light }
              Accessible.name: root.batteryAvailable ? "Battery at " + Data.SystemData.batteryPercent + " percent" : "Battery unavailable"
            }
            Text {
              visible: root.batteryAvailable
              text: "%"
              color: root.batteryAccent
              font { family: root.tokens.mono; pixelSize: 18 }
              Layout.alignment: Qt.AlignBottom
              Layout.bottomMargin: 10
            }
          }
          Caption {
            text: !root.batteryAvailable ? "No battery data" : ({Charging: "Charging", Discharging: "On battery", FullyCharged: "Fully charged", PendingCharge: "Waiting to charge", PendingDischarge: "Waiting to discharge", Empty: "Battery empty"})[Data.SystemData.batteryState] || "Unknown status"
          }
        }
        Item {
          Layout.preferredWidth: 72
          Layout.preferredHeight: 40
          Accessible.ignored: true
          Rectangle {
            width: 66; height: 36; y: 2
            radius: 9
            color: Qt.alpha(root.batteryAccent, 0.035)
            border.color: Qt.alpha(root.batteryAccent, 0.45)
            Row {
              anchors { fill: parent; margins: 5 }
              spacing: 3
              Repeater {
                model: 5
                Rectangle {
                  required property int index
                  width: 8.8; height: 26; radius: 3
                  color: Qt.alpha(root.batteryAccent, root.batteryLevel > index / 5 ? 0.85 : 0.1)
                }
              }
            }
          }
          Rectangle { x: 68; y: 13; width: 4; height: 14; radius: 2; color: Qt.alpha(root.batteryAccent, 0.45) }
        }
      }
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: 3
        radius: 1.5
        color: Qt.alpha(root.batteryAccent, 0.1)
        Rectangle {
          width: parent.width * root.batteryLevel
          height: parent.height; radius: parent.radius
          color: root.batteryAccent
          Behavior on width { NumberAnimation { duration: root.tokens.hoverDuration } }
        }
      }
    }
    Section {
      RowLayout {
        Layout.fillWidth: true
        Eyebrow { text: "POWER PROFILE" }
        Text {
          text: root.power.profilePending ? "Verifying…" : root.profileLabel
          color: root.tokens.muted
          font { family: root.tokens.font; pixelSize: 10 }
        }
      }
      GridLayout {
        Layout.fillWidth: true
        columns: root.compact ? 1 : 3
        columnSpacing: 6; rowSpacing: 6
        Repeater {
          model: [{name: "power-saver", label: "Power saver"}, {name: "balanced", label: "Balanced"}, {name: "performance", label: "Performance"}]
          Action {
            id: profile
            required property var modelData
            Layout.preferredWidth: 1
            implicitHeight: root.compact ? 40 : 72
            text: modelData.label
            selected: root.power.profilesAvailable && root.power.profile === modelData.name
            enabled: root.power.profilesAvailable && !root.power.profilePending && (modelData.name !== "performance" || root.power.performanceAvailable)
            contentItem: GridLayout {
              columns: root.compact ? 2 : 1
              columnSpacing: 8
              rowSpacing: 6
              ProfileIcon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                profileName: profile.modelData.name
                ink: profile.selected ? root.tokens.cyan : root.tokens.muted
              }
              Text {
                Layout.fillWidth: true
                text: profile.text
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: profile.selected ? root.tokens.cyan : root.tokens.text
                font { family: root.tokens.font; pixelSize: 10; weight: Font.Medium }
              }
            }
            onClicked: root.power.chooseProfile(modelData.name)
          }
        }
      }
      Diagnostic { text: root.power.profileError }
    }
    Section {
      RowLayout {
        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 5
          Eyebrow { text: "CAFFEINE" }
          Caption {
            text: root.power.caffeinePending ? "Verifying…" : root.power.caffeineActive ? "Keeping awake" : root.power.caffeineSaved ? "Saved · service inactive" : "Automatic sleep"
            color: root.power.caffeineActive ? root.tokens.cyan : root.tokens.text
            font { pixelSize: 13; weight: Font.Medium }
          }
          Caption { text: "Keeps your device awake while you work." }
        }
        Switch {
          id: caffeineToggle
          objectName: "powerCaffeineToggle"
          implicitWidth: 44; implicitHeight: 32
          checked: root.power.caffeineSaved
          enabled: root.power.caffeineAvailable && !root.power.caffeinePending
          opacity: enabled ? 1 : 0.4
          focusPolicy: Qt.StrongFocus
          Accessible.name: "Caffeine"
          Accessible.description: "Preference " + (root.power.caffeineSaved ? "on" : "off") + (root.power.caffeineActive ? ", service active" : ", service inactive")
          onToggled: root.power.caffeineToggle()
          indicator: Rectangle {
            x: 2; y: (caffeineToggle.height - height) / 2
            implicitWidth: 40; implicitHeight: 24; radius: 12
            color: caffeineToggle.checked ? root.tokens.cyan : Qt.alpha(root.tokens.muted, 0.15)
            border.color: caffeineToggle.visualFocus ? root.tokens.gold : root.tokens.border
            Rectangle {
              x: caffeineToggle.checked ? 19 : 3; y: 3
              width: 18; height: 18; radius: 9
              color: caffeineToggle.checked ? root.tokens.background : root.tokens.muted
              Behavior on x { NumberAnimation { duration: root.tokens.hoverDuration } }
            }
          }
          contentItem: Item {}
        }
      }
      Diagnostic { text: root.power.caffeineError }
    }
    Section {
      Eyebrow { text: "BATTERY CARE"; color: root.tokens.gold }
      RowLayout {
        Layout.fillWidth: true
        Caption {
          text: "Charge limit"
          color: root.tokens.text
          font { pixelSize: 14; weight: Font.Medium }
        }
        Text {
          text: root.power.chargeAvailable && root.power.chargeCurrent > 0 ? root.power.chargeCurrent + "%" : "—"
          color: root.tokens.gold
          font { family: root.tokens.mono; pixelSize: 20 }
        }
      }
      Caption {
        text: !root.power.chargeAvailable ? "Unavailable on this device" : root.power.chargePending ? "Authenticating / verifying…" : root.power.chargeActive ? "Verified limit · policy active" : root.power.chargeSaved > 0 ? "Saved · not applied" : "No saved policy"
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
          model: [60, 80, 100]
          Action {
            required property int modelData
            Layout.preferredWidth: 1
            text: modelData + "%"
            selected: Number(threshold.text) === modelData
            enabled: root.power.chargeAvailable && !root.power.chargePending
            Accessible.name: "Select charge limit of " + modelData + " percent"
            onClicked: threshold.text = String(modelData)
          }
        }
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        TextField {
          id: threshold
          objectName: "powerChargeThreshold"
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          implicitHeight: 38
          placeholderText: "1–100 %"
          color: root.tokens.text
          placeholderTextColor: root.tokens.muted
          selectionColor: root.tokens.cyan
          selectedTextColor: root.tokens.background
          font { family: root.tokens.mono; pixelSize: 12 }
          leftPadding: 12; rightPadding: 12
          enabled: root.power.chargeAvailable && !root.power.chargePending
          opacity: enabled ? 1 : 0.4
          validator: IntValidator { bottom: 1; top: 100 }
          Accessible.name: "Charge limit percentage"
          background: Rectangle {
            radius: 8
            color: root.tokens.surface
            border.color: threshold.activeFocus ? root.tokens.gold : root.tokens.border
          }
        }
        Action {
          Layout.fillWidth: false
          text: "Apply"
          enabled: root.power.chargeAvailable && !root.power.chargePending && threshold.acceptableInput && threshold.text !== ""
          onClicked: root.power.chargeApply(threshold.text)
        }
      }
      Caption {
        visible: root.power.chargeAvailable && root.power.chargeSaved > 0 && root.power.chargeSaved !== root.power.chargeCurrent
        text: "Saved preference: " + root.power.chargeSaved + "%"
      }
      Caption { text: "Stops charging at the selected level. Does not discharge the battery." }
      Diagnostic { text: root.power.chargeError }
    }
    Section {
      Eyebrow { text: "SESSION" }
      GridLayout {
        Layout.fillWidth: true
        columns: root.compact ? 1 : 2
        columnSpacing: 8; rowSpacing: 8
        Repeater {
          model: [{action: "lock", label: "Lock", symbol: "󰌾"}, {action: "suspend", label: "Suspend", symbol: "󰒲"}, {action: "logout", label: "Log out", symbol: "󰍃"}, {action: "reboot", label: "Restart", symbol: "󰜉"}, {action: "poweroff", label: "Shut down", symbol: "󰐥"}]
          Action {
            required property var modelData
            Layout.preferredWidth: 1
            Layout.columnSpan: modelData.action === "poweroff" && !root.compact ? 2 : 1
            text: modelData.label
            symbol: modelData.symbol
            enabled: !Data.SessionData.pending && Data.SessionData.confirmation === ""
            destructive: modelData.action === "poweroff"
            onClicked: Data.SessionData.ask(modelData.action)
          }
        }
      }
      Caption { visible: Data.SessionData.pending; text: "Processing session action…" }
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: confirmationBody.implicitHeight + 24
        visible: Data.SessionData.confirmation !== ""
        radius: 8
        color: Qt.alpha(root.tokens.alert, 0.055)
        border.color: Qt.alpha(root.tokens.alert, 0.2)
        ColumnLayout {
          id: confirmationBody
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
          spacing: 10
          Caption {
            text: "Confirm " + ({logout: "log out of this Hyprland instance", reboot: "restart", poweroff: "shutdown"}[Data.SessionData.confirmation] || "") + "?"
            color: root.tokens.alert
            font.weight: Font.Medium
          }
          Caption { text: "Save your work before continuing." }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Action { text: "Cancel"; onClicked: Data.SessionData.cancel() }
            Action { text: "Confirm"; destructive: true; onClicked: Data.SessionData.confirm() }
          }
        }
      }
      Diagnostic { text: Data.SessionData.error }
    }
  }
}
