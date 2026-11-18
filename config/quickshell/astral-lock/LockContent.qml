pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../common" as Common

Rectangle {
  id: root
  required property Common.Theme tokens
  required property var settings
  required property var media
  property string displayName: ""
  property url avatar: ""
  property date dateTime: new Date()
  property bool secure: false
  property bool busy: false
  property bool promptReady: false
  property bool error: false
  property bool unlocking: false
  property real exitProgress: 0
  property real entranceProgress: 0
  property string message: ""
  property string busyDetail: "Checking your password securely."
  signal begin()
  signal respond(var field)
  function clear(): void { password.clear(); }
  function focusPrompt(): void {
    if (!secure || !promptReady || busy || unlocking || password.activeFocus) return;
    password.forceActiveFocus();
  }
  function submit(): void {
    if (!secure || busy || unlocking) return;
    if (promptReady) {
      if (password.length) respond(password);
    } else begin();
  }
  onSecureChanged: {
    clear();
    if (secure) entrance.restart();
    else { entrance.stop(); entranceProgress = 0; }
  }
  Component.onCompleted: {
    if (secure) entrance.restart();
    // A surface rebuilt after resume can be born with the prompt already ready.
    if (secure && promptReady) Qt.callLater(root.focusPrompt);
  }
  NumberAnimation {
    id: entrance
    target: root; property: "entranceProgress"
    from: 0; to: 1
    duration: root.settings.value.animations ? 360 : 0
    easing.type: Easing.OutCubic
  }
  // Re-enabling the field after a PAM check also needs to bring focus back.
  onBusyChanged: {
    clear();
    if (!busy) Qt.callLater(root.focusPrompt);
  }
  onPromptReadyChanged: {
    clear();
    if (promptReady) Qt.callLater(root.focusPrompt);
  }
  // A VT switch or a suspend removes the keyboards, which makes Qt drop the
  // field's focus item, and nothing gives it back when the keyboard returns.
  // Take the focus item back as soon as Qt drops it; the window itself may
  // stay inactive, but keys still reach the focused item.
  Window.onActiveFocusItemChanged: Qt.callLater(root.focusPrompt)
  color: tokens.background
  readonly property bool wide: width / Math.max(0.1, tokens.scale) >= 1000
  readonly property real factor: Math.max(0.1, Math.min(tokens.scale, width / (wide ? 1040 : 420), height / (showMusic && !wide ? 1000 : 720)))
  readonly property bool showProfile: settings.value.lockScreen.showProfile
  readonly property bool showMusic: settings.value.lockScreen.showMusic && !!media.player

  // Opaque native geometry: no desktop sampling or remote images.
  Item {
    anchors.fill: parent; clip: true
    opacity: 0.4 + 0.6 * root.entranceProgress * (1 - root.exitProgress)
    Rectangle {
      width: Math.max(root.width, root.height) * 0.95; height: width; radius: width / 2
      x: -width * 0.38; y: root.height * 0.17
      color: "transparent"; border { width: 1; color: Qt.alpha(root.tokens.cyan, 0.07) }
      Rectangle { anchors.centerIn: parent; width: parent.width * 0.73; height: width; radius: width / 2; color: Qt.alpha(root.tokens.cyan, 0.018); border.color: Qt.alpha(root.tokens.cyan, 0.06) }
    }
    Rectangle {
      width: root.width * 0.6; height: 1; rotation: -35
      x: root.width * 0.57; y: root.height * 0.13
      color: Qt.alpha(root.tokens.gold, 0.1)
    }
  }
  Item {
    id: canvas
    anchors.centerIn: parent
    width: root.width / root.factor; height: root.height / root.factor
    opacity: root.entranceProgress * (1 - root.exitProgress)
    scale: root.factor * (0.975 + 0.025 * root.entranceProgress + 0.018 * root.exitProgress)
    transform: Translate { y: (1 - root.entranceProgress) * 14 - root.exitProgress * 16 }
    RowLayout {
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 32 }
      spacing: 8
      Text { text: "✦"; color: root.tokens.cyan; font.pixelSize: 18 }
      Text { text: "A S T R A L"; color: root.tokens.text; font { family: root.tokens.mono; pixelSize: 12 } }
      Item { Layout.fillWidth: true }
      Text { text: root.unlocking ? "\uf09c" : "\uf023"; color: root.tokens.muted; font { family: root.tokens.mono; pixelSize: 12 } }
      Text { text: root.unlocking ? "ACCESS CONFIRMED" : "SESSION LOCKED"; color: root.tokens.muted; font { family: root.tokens.mono; pixelSize: 10; letterSpacing: 1.2 } }
    }
    GridLayout {
      id: composition
      anchors.centerIn: parent
      width: Math.min(parent.width - 96, root.wide ? 1040 : 400)
      columns: root.wide ? 2 : 1
      columnSpacing: 96; rowSpacing: 32
      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: root.wide ? 520 : 400
        Layout.alignment: Qt.AlignVCenter
        spacing: 8
        Text {
          Layout.fillWidth: true
          text: root.dateTime.toLocaleDateString(Qt.locale("en_US"), "dddd, d MMMM")
          color: root.tokens.lavender
          horizontalAlignment: root.wide ? Text.AlignLeft : Text.AlignHCenter
          font { family: root.tokens.font; pixelSize: 14; weight: Font.Medium }
        }
        RowLayout {
          Layout.alignment: root.wide ? Qt.AlignLeft : Qt.AlignHCenter
          spacing: 8
          Text {
            objectName: "lockClock"
            text: root.settings.value.clockFormat === "24h" ? Qt.formatDateTime(root.dateTime, "HH:mm")
              : root.dateTime.toLocaleTimeString(Qt.locale("en_US"), "hh:mm AP").split(" ")[0]
            color: root.tokens.text
            font { family: root.tokens.font; pixelSize: root.wide ? 128 : 88; weight: Font.ExtraLight; letterSpacing: -4 }
          }
          Text {
            visible: root.settings.value.clockFormat !== "24h"
            text: root.dateTime.toLocaleTimeString(Qt.locale("en_US"), "AP")
            color: root.tokens.muted
            Layout.alignment: Qt.AlignBottom; Layout.bottomMargin: root.wide ? 28 : 18
            font { family: root.tokens.mono; pixelSize: 12 }
          }
        }
        Text {
          visible: root.wide
          Layout.topMargin: 4
          text: "A moment of pause."
          color: root.tokens.muted
          font { family: root.tokens.font; pixelSize: 16; weight: Font.Light }
        }
        LockMedia {
          objectName: "lockMedia"
          visible: root.showMusic && root.wide
          Layout.fillWidth: true; Layout.topMargin: 32
          Layout.maximumWidth: 440
          tokens: root.tokens; media: root.media
        }
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 380
        Layout.alignment: Qt.AlignVCenter
        spacing: 16
        Rectangle {
          id: accessCard
          objectName: "lockAccessCard"
          Layout.fillWidth: true
          implicitHeight: access.implicitHeight + 48
          color: root.tokens.surface
          radius: root.tokens.panelRadius; border.color: root.tokens.border
          ColumnLayout {
            id: access
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
            spacing: 20
            RowLayout {
              Layout.fillWidth: true; spacing: 16
              Rectangle {
                id: avatarFrame
                visible: root.showProfile
                Layout.preferredWidth: 56; Layout.preferredHeight: 56; radius: 28
                color: root.tokens.raised
                border.width: 1; border.color: Qt.alpha(root.tokens.cyan, 0.3)
                Common.RoundedClip {
                  anchors.fill: parent; anchors.margins: 3
                  radius: height / 2
                  Image {
                    id: photo
                    anchors.fill: parent
                    source: root.avatar.toString().startsWith("file:") || root.avatar.toString().startsWith("/") ? root.avatar : ""
                    fillMode: Image.PreserveAspectCrop
                  }
                }
                Text {
                  anchors.centerIn: parent; visible: photo.status !== Image.Ready
                  text: root.displayName.trim().split(/\s+/).map(word => word[0] || "").slice(0, 2).join("").toUpperCase() || "?"
                  color: root.tokens.cyan; font { family: root.tokens.mono; pixelSize: 18 }
                }
              }
              ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Text { text: "Welcome back"; color: root.tokens.muted; font { family: root.tokens.font; pixelSize: 12 } }
                Text {
                  Layout.fillWidth: true
                  text: root.showProfile ? root.displayName : "Your space awaits"
                  textFormat: Text.PlainText; elide: Text.ElideRight
                  color: root.tokens.text; font { family: root.tokens.font; pixelSize: 18; weight: Font.DemiBold }
                }
              }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.hairline }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 8
              Text { text: "Password"; color: root.tokens.muted; font { family: root.tokens.font; pixelSize: 12 } }
              TextField {
                id: password
                objectName: "lockPassword"
                // The only keyboard target of the lock surface: declaring focus
                // lets Qt restore it when the window regains the keyboard.
                focus: true
                Layout.fillWidth: true; Layout.preferredHeight: 48
                enabled: root.secure && root.promptReady && !root.busy && !root.unlocking
                echoMode: TextInput.Password; passwordMaskDelay: 0
                selectByMouse: false; persistentSelection: false
                inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                placeholderText: root.busy ? "Verifying…" : "Enter your password"
                leftPadding: 16; rightPadding: 16
                color: root.tokens.text; placeholderTextColor: root.tokens.muted
                font { family: root.tokens.mono; pixelSize: 13; letterSpacing: password.length > 0 ? 4 : 0 }
                background: Rectangle {
                  id: fieldFrame
                  radius: root.tokens.rowRadius; color: root.tokens.sunken
                  border.width: password.activeFocus ? 2 : 1
                  border.color: root.error ? root.tokens.alert
                    : password.activeFocus ? root.tokens.cyan
                    : fieldHover.hovered && password.enabled ? root.tokens.muted
                    : root.tokens.border
                  HoverHandler { id: fieldHover }
                  Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
                }
                Keys.onPressed: event => {
                  if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)
                      || event.matches(StandardKey.Paste) || event.matches(StandardKey.SelectAll)
                      || (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))
                      || event.key === Qt.Key_Insert || event.key === Qt.Key_Menu) event.accepted = true;
                  if (event.key === Qt.Key_Escape) { root.clear(); event.accepted = true; }
                }
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: password.forceActiveFocus() }
                // Focus can drop when the surface loses the seat keyboard across
                // suspend; keep what was typed so it is not erased mid-entry.
                onAccepted: root.submit()
              }
            }
            // Always reserve this space so messages never shift the field.
            RowLayout {
              Layout.fillWidth: true; Layout.preferredHeight: 40
              spacing: 8
              BusyIndicator {
                objectName: "lockBusy"
                visible: root.busy; running: root.busy
                Layout.preferredWidth: 20; Layout.preferredHeight: 20
                palette.dark: root.tokens.cyan
              }
              Text {
                objectName: "lockAuthStatus"
                Layout.fillWidth: true
                text: !root.secure ? "Securing the session…" : root.message || (root.busy ? "Verifying password…" : "Press Enter to return to your session.")
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: root.error ? root.tokens.alert : root.tokens.muted
                font { family: root.tokens.font; pixelSize: 12 }
                Accessible.role: Accessible.StaticText
              }
            }
            Item {
              Layout.fillWidth: true; Layout.preferredHeight: 28
              Text {
                objectName: "lockWaitDetail"
                anchors.fill: parent; visible: root.busy
                text: root.busyDetail; textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: root.tokens.muted; font { family: root.tokens.font; pixelSize: 11 }
              }
            }
            Button {
              id: authenticate
              objectName: "lockAuthenticate"
              focusPolicy: Qt.NoFocus
              Layout.fillWidth: true; Layout.preferredHeight: 46
              enabled: root.secure && !root.busy && !root.unlocking && (!root.promptReady || password.length > 0)
              text: root.unlocking ? "Access confirmed" : root.busy ? "Verifying…" : root.promptReady ? "Unlock" : "Retry"
              onClicked: root.submit()
              contentItem: Text {
                text: authenticate.text; color: root.tokens.background
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                font { family: root.tokens.font; pixelSize: 14; weight: Font.DemiBold }
              }
              background: Rectangle {
                radius: root.tokens.controlRadius
                color: authenticate.down ? Qt.alpha(root.tokens.cyan, 0.85)
                  : authenticate.hovered && authenticate.enabled ? Qt.lighter(root.tokens.cyan, 1.08)
                  : root.tokens.cyan
                opacity: authenticate.enabled ? 1 : 0.4
                border.width: authenticate.visualFocus ? 2 : 0
                border.color: root.tokens.text
                Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
              }
            }
          }
        }
        LockMedia {
          objectName: "lockMediaCompact"
          visible: root.showMusic && !root.wide
          Layout.fillWidth: true
          tokens: root.tokens; media: root.media
        }
      }
    }
    Text {
      anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 24 }
      text: "YOUR SESSION CONTINUES, AT YOUR PACE."
      color: root.tokens.muted; opacity: 0.6
      font { family: root.tokens.mono; pixelSize: 10; letterSpacing: 1.2 }
    }
  }
}
