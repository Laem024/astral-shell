import QtQuick
import QtQuick.Controls

Item {
  id: card
  required property var tokens
  required property var user
  required property int userIndex
  required property int userCount
  required property var session
  required property int sessionIndex
  required property int sessionCount

  property bool busy: false
  property bool error: false
  property string message: ""

  signal submitted(string password)
  signal userSelected(int index)
  signal sessionSelected(int index)

  implicitWidth: card.tokens.panelWidth
  implicitHeight: panel.height

  transform: Translate { id: shakeTranslate }

  function initials(value) {
    var words = String(value || "").trim().split(/\s+/)
    var result = ""
    for (var i = 0; i < words.length && result.length < 2; i++)
      result += (words[i][0] || "")
    return result.toUpperCase() || "?"
  }

  function focusPassword() {
    passwordField.forceInputFocus()
  }

  function clearPassword() {
    passwordField.clear()
  }

  function shake() {
    if (card.tokens.animations)
      shakeAnimation.restart()
  }

  function submit() {
    if (card.busy || card.sessionCount === 0)
      return
    if (card.user.needsPassword !== false && passwordField.text.length === 0)
      return
    var value = passwordField.text
    passwordField.clear()
    card.submitted(value)
  }

  SequentialAnimation {
    id: shakeAnimation
    NumberAnimation { target: shakeTranslate; property: "x"; from: 0; to: -8; duration: 55; easing.type: Easing.OutQuad }
    NumberAnimation { target: shakeTranslate; property: "x"; from: -8; to: 8; duration: 90; easing.type: Easing.InOutQuad }
    NumberAnimation { target: shakeTranslate; property: "x"; from: 8; to: -5; duration: 80; easing.type: Easing.InOutQuad }
    NumberAnimation { target: shakeTranslate; property: "x"; from: -5; to: 0; duration: 70; easing.type: Easing.OutQuad }
  }

  // Ambient halo around the glass.
  Rectangle {
    anchors.fill: panel
    anchors.margins: -16
    radius: card.tokens.panelRadius + 16
    color: "transparent"
    border.width: 1
    border.color: Qt.alpha(card.tokens.cyan, 0.09)
  }

  Rectangle {
    anchors.fill: panel
    anchors.margins: -36
    radius: card.tokens.panelRadius + 36
    color: "transparent"
    border.width: 1
    border.color: Qt.alpha(card.tokens.cyan, 0.04)
  }

  // Layered shadow instead of a blur effect, so no extra Qt modules are
  // needed inside the greeter.
  Rectangle {
    x: 0
    y: 22
    width: panel.width
    height: panel.height
    radius: card.tokens.panelRadius + 8
    color: Qt.rgba(0, 0, 0, 0.2)
  }

  Rectangle {
    x: 4
    y: 10
    width: panel.width - 8
    height: panel.height
    radius: card.tokens.panelRadius + 3
    color: Qt.rgba(0, 0, 0, 0.2)
  }

  Rectangle {
    id: panel
    width: parent.width
    height: content.implicitHeight + 74
    radius: card.tokens.panelRadius
    color: "transparent"

    Rectangle {
      anchors.fill: parent
      radius: panel.radius
      color: card.tokens.glass
      border.width: 1
      border.color: card.tokens.glassEdge
    }

    Rectangle {
      anchors.fill: parent
      radius: panel.radius
      gradient: Gradient {
        GradientStop { position: 0.0; color: card.tokens.glassSheen }
        GradientStop { position: 0.34; color: "transparent" }
        GradientStop { position: 0.76; color: Qt.rgba(0, 0, 0, 0.03) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.1) }
      }
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      y: 1
      width: parent.width * 0.54
      height: 1
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: 0.5; color: Qt.alpha("#FFFFFF", 0.42) }
        GradientStop { position: 1.0; color: "transparent" }
      }
    }

    Column {
      id: content
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        leftMargin: 38
        rightMargin: 38
        topMargin: 36
      }
      spacing: 18

      Item {
        id: identity
        width: parent.width
        height: identityColumn.height

        Column {
          id: identityColumn
          width: parent.width
          spacing: 11

          Text {
            width: parent.width
            text: "WELCOME BACK"
            color: card.tokens.muted
            horizontalAlignment: Text.AlignHCenter
            font {
              family: card.tokens.mono
              pixelSize: 9
              letterSpacing: 2.2
            }
          }

          Item {
            width: parent.width
            height: card.tokens.showAvatar ? 74 : 0

            Item {
              width: 74
              height: 74
              anchors.horizontalCenter: parent.horizontalCenter
              visible: card.tokens.showAvatar

              Rectangle {
                anchors.centerIn: parent
                width: parent.width + 18
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(card.tokens.cyan, 0.14)
              }

              Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: card.tokens.glassSoft
                border.width: 1
                border.color: Qt.alpha(card.tokens.cyan, 0.35)
              }

              Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: width / 2
                color: card.tokens.background
                clip: true

                Image {
                  id: avatar
                  anchors.fill: parent
                  source: card.tokens.customAvatar || (card.user.icon || "")
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true
                  cache: true
                  visible: status === Image.Ready
                }

                Text {
                  anchors.centerIn: parent
                  visible: !avatar.visible
                  text: card.initials(card.user.realName || card.user.name)
                  color: card.tokens.cyan
                  font {
                    family: card.tokens.mono
                    pixelSize: 22
                    weight: Font.Medium
                  }
                }
              }
            }
          }

          Text {
            width: parent.width
            text: card.user.realName || card.user.name || "User"
            color: card.tokens.text
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font {
              family: card.tokens.font
              pixelSize: 22
              weight: Font.Medium
              letterSpacing: 0.2
            }
          }

          Item {
            width: parent.width
            height: 12

            Row {
              anchors.centerIn: parent
              spacing: 8

              Text {
                text: card.user.name ? "@" + card.user.name : ""
                color: card.tokens.muted
                font {
                  family: card.tokens.mono
                  pixelSize: 10
                }
              }

              Text {
                visible: card.userCount > 1
                text: "·  change account"
                color: card.tokens.muted
                font {
                  family: card.tokens.mono
                  pixelSize: 9
                  letterSpacing: 0.4
                }
              }
            }
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: card.userCount > 1 && !card.busy
          hoverEnabled: true
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: userPopup.open()
        }
      }

      Item {
        width: parent.width
        height: 10

        Rectangle {
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
          }
          width: parent.width / 2 - 18
          height: 1
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: card.tokens.glassLine }
          }
        }

        Rectangle {
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
          }
          width: parent.width / 2 - 18
          height: 1
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: card.tokens.glassLine }
            GradientStop { position: 1.0; color: "transparent" }
          }
        }

        Text {
          anchors.centerIn: parent
          text: "✦"
          color: Qt.alpha(card.tokens.cyan, 0.75)
          font.pixelSize: 8
        }
      }

      Column {
        width: parent.width
        spacing: 9

        Item {
          width: parent.width
          height: 12

          Text {
            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
            }
            text: "PASSWORD"
            color: card.tokens.muted
            font {
              family: card.tokens.mono
              pixelSize: 9
              letterSpacing: 1.6
            }
          }

          Text {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
            }
            visible: keyboard.capsLock
            text: "CAPS LOCK"
            color: card.tokens.gold
            font {
              family: card.tokens.mono
              pixelSize: 9
              letterSpacing: 1
            }
          }
        }

        AstralField {
          id: passwordField
          width: parent.width
          tokens: card.tokens
          placeholderText: card.busy ? "Checking…" : "Enter your password"
          error: card.error
          busy: card.busy
          onAccepted: card.submit()
          onEscapePressed: clear()
        }

        Text {
          width: parent.width
          height: 18
          text: card.error ? (card.message || "Incorrect password. Try again.")
            : card.busy ? "Checking your password…"
            : card.sessionCount === 0 ? "No desktop sessions are available."
            : "Press Enter to sign in."
          color: card.error ? card.tokens.alert : card.tokens.muted
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          verticalAlignment: Text.AlignVCenter
          opacity: card.error || card.busy ? 1 : 0.8
          font {
            family: card.tokens.font
            pixelSize: 12
          }
        }
      }

      AstralButton {
        width: parent.width
        tokens: card.tokens
        solid: true
        label: card.busy ? "Signing in…" : "Sign in"
        enabled: !card.busy && card.sessionCount > 0
          && (card.user.needsPassword === false || passwordField.text.length > 0)
        onClicked: card.submit()
      }

      Item {
        width: parent.width
        height: 1
        Rectangle {
          anchors.fill: parent
          color: card.tokens.glassLine
        }
      }

      Item {
        id: footer
        width: parent.width
        height: 28

        TextButton {
          id: sessionChip
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
          }
          visible: card.tokens.showSession
          tokens: card.tokens
          text: (card.session.name || "Session") + "  ▾"
          enabled: card.sessionCount > 0 && !card.busy
          onClicked: sessionPopup.open()
        }

        Row {
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
          }
          spacing: 16

          TextButton {
            visible: card.tokens.showPower && sddm.canPowerOff
            tokens: card.tokens
            text: "Power off"
            onClicked: sddm.powerOff()
          }
          TextButton {
            visible: card.tokens.showPower && sddm.canReboot
            tokens: card.tokens
            text: "Restart"
            onClicked: sddm.reboot()
          }
          TextButton {
            visible: card.tokens.showPower && sddm.canSuspend
            tokens: card.tokens
            text: "Suspend"
            onClicked: sddm.suspend()
          }
        }
      }
    }
  }

  Popup {
    id: userPopup
    parent: card
    width: card.width
    height: Math.min(300, userList.contentHeight + 16)
    x: 0
    y: Math.max(8, (card.height - height) / 2)
    padding: 8
    modal: true
    focus: true
    dim: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    background: Rectangle {
      color: card.tokens.surface
      radius: 18
      border.width: 1
      border.color: card.tokens.glassEdge
    }

    contentItem: ListView {
      id: userList
      width: card.width - 16
      height: Math.min(contentHeight, 280)
      clip: true
      spacing: 4
      model: userModel
      currentIndex: card.userIndex
      keyNavigationEnabled: true

      delegate: Rectangle {
        width: userList.width
        height: 56
        radius: 11
        color: userList.currentIndex === index ? Qt.alpha(card.tokens.cyan, 0.14)
          : userMouse.containsMouse ? Qt.alpha(card.tokens.text, 0.05)
          : "transparent"

        Row {
          anchors.fill: parent
          anchors.margins: 8
          spacing: 10

          Rectangle {
            width: 40
            height: 40
            radius: 20
            color: card.tokens.background
            border.width: 1
            border.color: card.tokens.glassEdge

            Image {
              id: pickerAvatar
              anchors.fill: parent
              anchors.margins: 3
              source: model.icon || ""
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              cache: true
              visible: status === Image.Ready
            }

            Text {
              anchors.centerIn: parent
              visible: pickerAvatar.status !== Image.Ready
              text: card.initials(model.realName || model.name)
              color: card.tokens.cyan
              font {
                family: card.tokens.mono
                pixelSize: 13
              }
            }
          }

          Item {
            width: parent.width - 50
            height: 40

            Column {
              width: parent.width
              anchors.verticalCenter: parent.verticalCenter
              spacing: 2

              Text {
                width: parent.width
                text: model.realName || model.name
                color: card.tokens.text
                elide: Text.ElideRight
                font {
                  family: card.tokens.font
                  pixelSize: 14
                }
              }

              Text {
                width: parent.width
                text: model.name
                color: card.tokens.muted
                elide: Text.ElideRight
                font {
                  family: card.tokens.mono
                  pixelSize: 10
                }
              }
            }
          }
        }

        MouseArea {
          id: userMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            userList.currentIndex = index
            card.clearPassword()
            card.userSelected(index)
            userPopup.close()
          }
        }
      }

      Keys.onReturnPressed: {
        if (userList.currentIndex >= 0) {
          card.clearPassword()
          card.userSelected(userList.currentIndex)
          userPopup.close()
        }
      }
      Keys.onEnterPressed: {
        if (userList.currentIndex >= 0) {
          card.clearPassword()
          card.userSelected(userList.currentIndex)
          userPopup.close()
        }
      }
    }

    onOpened: {
      userList.currentIndex = card.userIndex
      userList.forceActiveFocus()
      if (card.userIndex >= 0)
        userList.positionViewAtIndex(card.userIndex, ListView.Center)
    }
    onClosed: Qt.callLater(() => { if (card.visible) card.focusPassword() })
  }

  Popup {
    id: sessionPopup
    parent: card
    width: card.width - 2 * content.x
    height: Math.min(300, sessionList.contentHeight + 16)
    x: content.x
    y: Math.max(8, content.y + footer.y + sessionChip.y - height - 10)
    padding: 8
    modal: true
    focus: true
    dim: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    background: Rectangle {
      color: card.tokens.surface
      radius: 18
      border.width: 1
      border.color: card.tokens.glassEdge
    }

    contentItem: ListView {
      id: sessionList
      width: card.width - 16
      height: Math.min(contentHeight, 280)
      clip: true
      spacing: 4
      model: sessionModel
      currentIndex: card.sessionIndex
      keyNavigationEnabled: true

      delegate: Rectangle {
        width: sessionList.width
        height: 54
        radius: 11
        color: sessionList.currentIndex === index ? Qt.alpha(card.tokens.cyan, 0.14)
          : sessionMouse.containsMouse ? Qt.alpha(card.tokens.text, 0.05)
          : "transparent"

        Column {
          anchors {
            left: parent.left
            right: parent.right
            leftMargin: 14
            rightMargin: 14
            verticalCenter: parent.verticalCenter
          }
          spacing: 3

          Text {
            width: parent.width
            text: model.name
            color: card.tokens.text
            elide: Text.ElideRight
            font {
              family: card.tokens.font
              pixelSize: 14
              weight: Font.Medium
            }
          }

          Text {
            width: parent.width
            visible: (model.comment || "").length > 0
            text: model.comment || ""
            color: card.tokens.muted
            elide: Text.ElideRight
            font {
              family: card.tokens.mono
              pixelSize: 9
            }
          }
        }

        MouseArea {
          id: sessionMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            sessionList.currentIndex = index
            card.sessionSelected(index)
            sessionPopup.close()
          }
        }
      }

      Keys.onReturnPressed: {
        if (sessionList.currentIndex >= 0) {
          card.sessionSelected(sessionList.currentIndex)
          sessionPopup.close()
        }
      }
      Keys.onEnterPressed: {
        if (sessionList.currentIndex >= 0) {
          card.sessionSelected(sessionList.currentIndex)
          sessionPopup.close()
        }
      }
    }

    onOpened: {
      sessionList.currentIndex = card.sessionIndex
      sessionList.forceActiveFocus()
      if (card.sessionIndex >= 0)
        sessionList.positionViewAtIndex(card.sessionIndex, ListView.Center)
    }
    onClosed: Qt.callLater(() => { if (card.visible) card.focusPassword() })
  }
}
