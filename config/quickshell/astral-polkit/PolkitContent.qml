pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell

Item {
  id: root
  required property var service
  required property var tokens
  property real reveal: 1
  readonly property bool allowed: !service.blocked

  readonly property var flow: service.flow
  readonly property bool responseRequired: !!(flow && flow.isResponseRequired)
  readonly property bool hasIdentities: !!(flow && flow.identities && flow.identities.length > 1)
  readonly property string messageText: flow && flow.message ? flow.message : "Authentication is required."
  readonly property string promptText: flow && flow.inputPrompt ? String(flow.inputPrompt).trim() : ""
  readonly property string supplementary: flow && flow.supplementaryMessage ? flow.supplementaryMessage : ""
  readonly property bool supplementaryError: !!(flow && flow.supplementaryIsError)
  readonly property string identityName: {
    const identity = flow ? flow.selectedIdentity : null;
    if (!identity) return "";
    return identity.displayName || identity.string || "";
  }
  readonly property string iconSource: {
    const requested = flow && flow.iconName ? flow.iconName : "";
    return (requested && Quickshell.iconPath(requested, true))
      || Quickshell.iconPath("system-lock-screen", true)
      || Quickshell.iconPath("dialog-password", true);
  }
  readonly property bool failed: !!(flow && flow.failed)

  property string password: ""
  property bool details: false
  property bool submitting: false

  signal cancelRequested()
  signal submitRequested(string value)

  function focusInput(): void {
    if (!root.responseRequired) return;
    Qt.callLater(() => {
      if (root.visible && field.visible) field.forceActiveFocus();
    });
  }
  function clearPassword(): void {
    root.password = "";
    field.text = "";
  }
  function settle(): void {
    root.submitting = false;
    root.clearPassword();
  }
  function submit(): void {
    if (!root.flow || !root.allowed || !root.responseRequired || root.submitting) return;
    if (root.password.length === 0) return;
    root.submitting = true;
    const value = root.password;
    root.clearPassword();
    root.submitRequested(value);
  }
  function cancel(): void {
    root.settle();
    root.cancelRequested();
  }
  function reset(): void {
    root.settle();
    root.details = false;
  }

  onAllowedChanged: if (!allowed) reset()
  Component.onDestruction: clearPassword()
  Component.onCompleted: root.focusInput()

  Timer {
    id: focusRetry
    interval: 100
    repeat: true
    running: root.allowed && root.responseRequired && !field.activeFocus
    onTriggered: root.focusInput()
  }

  Connections {
    target: root.service
    function onResponseCleared(): void { root.clearPassword(); }
    function onRequestFinished(): void { root.reset(); }
    function onRequestStarted(): void {
      root.reset();
      root.focusInput();
    }
  }

  Connections {
    target: root.flow
    function onIsResponseRequiredChanged(): void {
      root.settle();
      root.focusInput();
    }
    function onSupplementaryMessageChanged(): void {
      if (root.supplementaryError) root.clearPassword();
      root.focusInput();
    }
    function onSelectedIdentityChanged(): void {
      root.settle();
      root.focusInput();
    }
  }

  Rectangle {
    anchors.fill: parent
    color: root.tokens.scrim
    opacity: root.reveal
  }

  // The overlay owns every pointer event while a request is pending.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    onPressed: mouse => { mouse.accepted = true; }
  }

  Rectangle {
    id: card
    anchors.centerIn: parent
    width: Math.max(1, Math.min(480, (root.width - 48) / root.tokens.scale))
    height: content.implicitHeight + root.tokens.section * 2
    Behavior on height { NumberAnimation { duration: root.tokens.entryDuration; easing.type: Easing.OutCubic } }
    scale: root.tokens.scale * (0.97 + 0.03 * root.reveal)
    transformOrigin: Item.Center
    color: root.tokens.surface
    radius: root.tokens.panelRadius
    border.width: 1
    border.color: root.tokens.border
    opacity: root.reveal
    Keys.onEscapePressed: root.cancel()

    // Empty card areas consume clicks; the controls below sit on top.
    MouseArea { anchors.fill: parent }

    // The accent paints the top border itself, starting where the corner
    // curve ends, so the edge stays 1px thick and never leaves the outline.
    Rectangle {
      x: card.radius
      y: 0
      width: Math.max(0, (card.width - card.radius * 2) * 0.55)
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: "transparent" }
        GradientStop { position: 0.1; color: Qt.alpha(root.tokens.cyan, 0.45) }
        GradientStop { position: 1; color: "transparent" }
      }
    }

    ColumnLayout {
      id: content
      anchors {
        top: parent.top
        left: parent.left
        right: parent.right
        margins: root.tokens.section
      }
      spacing: 16

      RowLayout {
        Layout.fillWidth: true
        spacing: 16

        Rectangle {
          Layout.alignment: Qt.AlignTop
          implicitWidth: 44
          implicitHeight: 44
          radius: root.tokens.cardRadius
          color: Qt.alpha(root.tokens.cyan, 0.1)
          border.width: 1
          border.color: Qt.alpha(root.tokens.cyan, 0.3)

          Image {
            id: icon
            anchors.centerIn: parent
            width: 22
            height: 22
            sourceSize.width: 44
            sourceSize.height: 44
            source: root.iconSource
            visible: false
            layer.enabled: true
          }
          MultiEffect {
            anchors.centerIn: parent
            width: 22
            height: 22
            visible: root.iconSource !== ""
            source: icon
            colorization: 1
            colorizationColor: root.tokens.cyan
          }
          Text {
            anchors.centerIn: parent
            visible: root.iconSource === ""
            text: "󰌾"
            color: root.tokens.cyan
            font { family: root.tokens.mono; pixelSize: 20 }
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: 4

          Text {
            Layout.fillWidth: true
            text: "AUTHENTICATION REQUIRED"
            color: root.tokens.cyan
            elide: Text.ElideRight
            font {
              family: root.tokens.mono
              pixelSize: 10
              letterSpacing: 1.4
            }
          }
          Text {
            Layout.fillWidth: true
            text: root.messageText
            color: root.tokens.text
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            textFormat: Text.PlainText
            lineHeight: 1.15
            font {
              family: root.tokens.font
              pixelSize: 15
              weight: Font.DemiBold
            }
          }
        }
      }

      // The requesting action and the user it will run as.
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: requestDetails.implicitHeight + root.tokens.padding * 2
        radius: root.tokens.rowRadius
        color: root.tokens.sunken
        border.width: 1
        border.color: root.tokens.border

        ColumnLayout {
          id: requestDetails
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: root.tokens.padding
          }
          spacing: 10

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              Layout.preferredWidth: 56
              Layout.alignment: Qt.AlignTop
              text: "Action"
              color: root.tokens.muted
              font { family: root.tokens.font; pixelSize: 12 }
            }
            Text {
              Layout.fillWidth: true
              text: root.flow && root.flow.actionId ? root.flow.actionId : "unknown"
              color: root.tokens.text
              wrapMode: Text.WrapAnywhere
              maximumLineCount: 2
              elide: Text.ElideRight
              textFormat: Text.PlainText
              font { family: root.tokens.mono; pixelSize: 11 }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
              Layout.preferredWidth: 56
              Layout.alignment: Qt.AlignTop
              text: "User"
              color: root.tokens.muted
              font { family: root.tokens.font; pixelSize: 12 }
            }
            Text {
              Layout.fillWidth: true
              visible: !root.hasIdentities
              text: root.identityName !== "" ? root.identityName : "Unknown user"
              color: root.tokens.text
              elide: Text.ElideRight
              textFormat: Text.PlainText
              font { family: root.tokens.font; pixelSize: 12 }
            }
            Flow {
              Layout.fillWidth: true
              visible: root.hasIdentities
              spacing: 6

              Repeater {
                model: root.flow ? root.flow.identities : []

                delegate: Rectangle {
                  id: chip
                  required property var modelData
                  readonly property bool selected: root.flow && root.flow.selectedIdentity
                    && root.flow.selectedIdentity.id === modelData.id
                    && root.flow.selectedIdentity.isGroup === modelData.isGroup
                  implicitWidth: chipText.implicitWidth + 20
                  implicitHeight: 26
                  radius: root.tokens.controlRadius
                  color: chip.selected ? Qt.alpha(root.tokens.cyan, 0.14)
                    : chipHover.hovered ? Qt.alpha(root.tokens.muted, 0.1)
                    : "transparent"
                  border.width: chip.selected ? 1.5 : 1
                  border.color: chip.selected ? Qt.alpha(root.tokens.cyan, 0.6) : root.tokens.border

                  Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData.displayName || chip.modelData.string || ""
                    color: chip.selected ? root.tokens.cyan : root.tokens.muted
                    font { family: root.tokens.font; pixelSize: 11; weight: chip.selected ? Font.DemiBold : Font.Normal }
                  }
                  HoverHandler { id: chipHover }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { root.settle(); root.service.select(chip.modelData); }
                  }
                }
              }
            }
          }
        }
      }

      Text {
        Layout.fillWidth: true
        visible: root.failed && !root.supplementaryError
        text: "Authentication failed. Please try again."
        color: root.tokens.alert
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        font { family: root.tokens.font; pixelSize: 12 }
      }

      Text {
        Layout.fillWidth: true
        visible: root.supplementary !== ""
        text: root.supplementary
        color: root.supplementaryError ? root.tokens.alert : root.tokens.muted
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        font { family: root.tokens.font; pixelSize: 12 }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 8
        visible: root.responseRequired

        Text {
          Layout.fillWidth: true
          text: root.promptText !== "" ? root.promptText : "Password"
          color: root.tokens.muted
          elide: Text.ElideRight
          font { family: root.tokens.font; pixelSize: 12 }
        }

        TextField {
          id: field
          Layout.fillWidth: true
          implicitHeight: 46
          leftPadding: 14
          rightPadding: 14
          enabled: !root.submitting
          selectByMouse: true
          passwordCharacter: "•"
          echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
          color: root.tokens.text
          selectionColor: root.tokens.cyan
          selectedTextColor: root.tokens.background
          placeholderTextColor: root.tokens.muted
          font { family: root.tokens.font; pixelSize: 14 }
          verticalAlignment: TextInput.AlignVCenter
          onTextChanged: if (root.password !== text) root.password = text
          onAccepted: root.submit()
          Accessible.name: root.promptText !== "" ? root.promptText : "Password"
          background: Rectangle {
            radius: root.tokens.rowRadius
            color: root.tokens.sunken
            border.width: field.activeFocus ? 2 : 1
            border.color: field.activeFocus
              ? root.tokens.cyan
              : root.failed ? Qt.alpha(root.tokens.alert, 0.7)
              : fieldHover.hovered && field.enabled ? root.tokens.muted
              : root.tokens.border
            HoverHandler { id: fieldHover }
            Behavior on border.color { ColorAnimation { duration: root.tokens.entryDuration } }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        visible: !root.responseRequired
        spacing: 8

        Rectangle {
          implicitWidth: 8
          implicitHeight: 8
          radius: 4
          color: root.tokens.cyan
          SequentialAnimation on opacity {
            running: !root.responseRequired
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
          }
        }
        Text {
          Layout.fillWidth: true
          text: "Waiting for authentication…"
          color: root.tokens.muted
          font { family: root.tokens.font; pixelSize: 12 }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        spacing: 8

        Text {
          visible: root.submitting
          text: "Checking credentials…"
          color: root.tokens.muted
          font { family: root.tokens.font; pixelSize: 12 }
        }

        Item { Layout.fillWidth: true }

        ActionButton {
          label: "Cancel"
          onClicked: root.cancel()
        }
        ActionButton {
          label: "Authenticate"
          primary: true
          visible: root.responseRequired
          enabled: !root.submitting && root.password.length > 0
          onClicked: root.submit()
        }
      }

      Item {
        Layout.fillWidth: true
        implicitHeight: detailsToggle.implicitHeight

        RowLayout {
          id: detailsToggle
          anchors.left: parent.left
          spacing: 6
          Text {
            text: root.details ? "▾" : "▸"
            color: root.tokens.muted
            font { family: root.tokens.mono; pixelSize: 10 }
          }
          Text {
            text: root.details ? "Hide details" : "Show details"
            color: detailsHover.hovered ? root.tokens.text : root.tokens.muted
            font { family: root.tokens.font; pixelSize: 11 }
          }
        }
        HoverHandler { id: detailsHover }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.details = !root.details
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        visible: root.details
        spacing: 4

        Text {
          text: "IDENTITIES"
          color: Qt.alpha(root.tokens.muted, 0.8)
          font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 1.2 }
        }
        Repeater {
          model: root.flow ? root.flow.identities : []
          delegate: Text {
            required property var modelData
            Layout.fillWidth: true
            text: (modelData.isGroup ? "group · " : "user · ") + (modelData.string || "")
            color: root.tokens.muted
            elide: Text.ElideRight
            textFormat: Text.PlainText
            font { family: root.tokens.mono; pixelSize: 10 }
          }
        }
      }
    }
  }

  component ActionButton: Rectangle {
    id: button
    property string label
    property bool primary: false
    signal clicked()

    implicitWidth: buttonLabel.implicitWidth + 32
    implicitHeight: 36
    radius: height / 2
    opacity: enabled ? 1 : 0.45
    color: primary ? (pointer.pressed ? Qt.alpha(root.tokens.cyan, 0.85) : pointer.containsMouse && enabled ? Qt.lighter(root.tokens.cyan, 1.08) : root.tokens.cyan)
      : !enabled ? "transparent"
      : pointer.pressed ? Qt.alpha(root.tokens.muted, 0.16) : pointer.containsMouse ? Qt.alpha(root.tokens.muted, 0.1) : "transparent"
    border.width: primary ? 0 : 1
    border.color: pointer.containsMouse && enabled && !primary ? Qt.alpha(root.tokens.muted, 0.5) : root.tokens.border

    Text {
      id: buttonLabel
      anchors.centerIn: parent
      text: button.label
      color: button.primary ? root.tokens.background : root.tokens.text
      font {
        family: root.tokens.font
        pixelSize: 12
        weight: Font.DemiBold
      }
    }
    MouseArea {
      id: pointer
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      enabled: button.enabled
      onClicked: button.clicked()
    }
  }
}
