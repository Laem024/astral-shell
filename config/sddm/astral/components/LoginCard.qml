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

  Rectangle {
    id: panel
    width: parent.width
    height: content.implicitHeight + 2 * card.tokens.section
    radius: card.tokens.panelRadius
    color: Qt.alpha(card.tokens.surface, 0.97)
    border.width: 1
    border.color: Qt.alpha(card.tokens.border, 0.6)

    Column {
      id: content
      anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        leftMargin: card.tokens.section
        rightMargin: card.tokens.section
        topMargin: card.tokens.section
      }
      spacing: card.tokens.inset

      Column {
        width: parent.width
        spacing: 6

        Text {
          text: "SIGN IN"
          color: card.tokens.cyan
          font { family: card.tokens.mono; pixelSize: 10; letterSpacing: 2 }
        }

        Text {
          text: "Make yourself at home."
          color: card.tokens.text
          font { family: card.tokens.font; pixelSize: 22; weight: Font.Light }
        }
      }

      Item {
        id: identity
        width: parent.width
        height: Math.max(avatar.visible ? avatar.height : 0, identityText.height)

        Avatar {
          id: avatar
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          visible: card.tokens.showAvatar
          tokens: card.tokens
          size: 96
          source: card.tokens.customAvatar || (card.user.icon || "")
          initials: card.initials(card.user.realName || card.user.name)
        }

        Column {
          id: identityText
          x: avatar.visible ? avatar.width + card.tokens.inset : 0
          width: Math.max(0, parent.width - x)
          anchors.verticalCenter: parent.verticalCenter
          spacing: card.tokens.gap
          Text {
            width: parent.width
            text: (card.user.realName || card.user.name || "User") + (card.userCount > 1 ? "  ▾" : "")
            color: card.tokens.text
            elide: Text.ElideRight
            font { family: card.tokens.font; pixelSize: card.tokens.titleSize; weight: Font.Medium }
          }
          Text {
            width: parent.width
            visible: (card.user.name || "").length > 0
            text: "@" + (card.user.name || "")
            color: card.tokens.muted
            elide: Text.ElideRight
            font { family: card.tokens.mono; pixelSize: card.tokens.captionSize + 1 }
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

      Rectangle {
        width: parent.width
        height: 1
        color: card.tokens.border
      }

      Column {
        width: parent.width
        spacing: card.tokens.gap

        Item {
          width: parent.width
          height: 14

          Text {
            anchors {
              left: parent.left
              verticalCenter: parent.verticalCenter
            }
            text: "PASSWORD"
            color: card.tokens.muted
            font {
              family: card.tokens.mono
              pixelSize: card.tokens.captionSize
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
              pixelSize: card.tokens.captionSize
              letterSpacing: 1.2
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
          font {
            family: card.tokens.font
            pixelSize: card.tokens.bodySize
          }
        }
      }

      AstralButton {
        width: parent.width
        height: card.tokens.buttonHeight
        tokens: card.tokens
        solid: true
        label: card.busy ? "Signing in…" : "Sign in"
        enabled: !card.busy && card.sessionCount > 0
          && (card.user.needsPassword === false || passwordField.text.length > 0)
        onClicked: card.submit()
      }

      Rectangle {
        id: sessionRow
        objectName: "sessionSelector"
        width: parent.width
        height: 40
        visible: card.tokens.showSession
        enabled: card.sessionCount > 0 && !card.busy
        radius: card.tokens.rowRadius
        color: sessionRowMouse.containsMouse && sessionRow.enabled ? Qt.alpha(card.tokens.cyan, 0.08) : "transparent"
        border.width: 1
        border.color: sessionRowMouse.containsMouse && sessionRow.enabled
          ? Qt.alpha(card.tokens.cyan, 0.6) : card.tokens.border
        opacity: sessionRow.enabled ? 1 : 0.4

        Text {
          anchors {
            left: parent.left
            leftMargin: 16
            verticalCenter: parent.verticalCenter
          }
          text: "SESSION"
          color: card.tokens.muted
          font {
            family: card.tokens.mono
            pixelSize: card.tokens.captionSize
            letterSpacing: 1.6
          }
        }

        Text {
          anchors {
            right: parent.right
            rightMargin: 16
            verticalCenter: parent.verticalCenter
          }
          width: parent.width - 120
          text: (card.session.name || "Session") + "  ▾"
          color: sessionRow.enabled && sessionRowMouse.containsMouse ? card.tokens.cyan : card.tokens.text
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideRight
          font {
            family: card.tokens.font
            pixelSize: card.tokens.bodySize
            weight: Font.Medium
          }
        }

        MouseArea {
          id: sessionRowMouse
          anchors.fill: parent
          enabled: sessionRow.enabled
          hoverEnabled: true
          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: sessionPopup.open()
        }
      }
    }
  }

  Popup {
    id: userPopup
    parent: card
    width: content.width
    height: Math.min(300, userList.contentHeight) + 16
    x: content.x
    y: Math.max(8, (card.height - height) / 2)
    padding: 8
    modal: true
    focus: true
    dim: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    background: Rectangle {
      color: card.tokens.surface
      radius: card.tokens.cardRadius
      border.width: 1
      border.color: card.tokens.border
    }

    contentItem: ListView {
      id: userList
      width: userPopup.availableWidth
      height: Math.min(contentHeight, 300)
      clip: true
      spacing: 4
      model: userModel
      currentIndex: card.userIndex
      keyNavigationEnabled: true

      delegate: Rectangle {
        width: userList.width
        height: 68
        radius: card.tokens.rowRadius
        color: userList.currentIndex === index ? Qt.alpha(card.tokens.cyan, 0.12)
          : userMouse.containsMouse ? Qt.alpha(card.tokens.text, 0.05)
          : "transparent"
        border.width: userList.currentIndex === index ? 1 : 0
        border.color: Qt.alpha(card.tokens.cyan, 0.6)

        Avatar {
          id: rowAvatar
          anchors {
            left: parent.left
            leftMargin: 8
            verticalCenter: parent.verticalCenter
          }
          tokens: card.tokens
          size: 48
          source: model.icon || ""
          initials: card.initials(model.realName || model.name)
        }

        Column {
          anchors {
            left: rowAvatar.right
            right: parent.right
            leftMargin: 12
            rightMargin: 12
            verticalCenter: parent.verticalCenter
          }
          spacing: 2

          Text {
            width: parent.width
            text: model.realName || model.name
            color: card.tokens.text
            elide: Text.ElideRight
            font {
              family: card.tokens.font
              pixelSize: card.tokens.labelSize
            }
          }

          Text {
            width: parent.width
            text: model.name
            color: card.tokens.muted
            elide: Text.ElideRight
            font {
              family: card.tokens.mono
              pixelSize: card.tokens.captionSize
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
    objectName: "sessionPopup"
    parent: sessionRow
    width: sessionRow.width
    height: Math.min(260, sessionList.contentHeight) + 16
    x: 0
    y: sessionRow.height + 8
    margins: 8
    padding: 8
    modal: true
    focus: true
    dim: false
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    background: Rectangle {
      color: card.tokens.surface
      radius: card.tokens.cardRadius
      border.width: 1
      border.color: card.tokens.border
    }

    contentItem: ListView {
      id: sessionList
      width: sessionPopup.availableWidth
      height: Math.min(contentHeight, 260)
      clip: true
      spacing: 4
      model: sessionModel
      currentIndex: card.sessionIndex
      keyNavigationEnabled: true

      delegate: Rectangle {
        width: sessionList.width
        height: 48
        radius: card.tokens.rowRadius
        color: sessionList.currentIndex === index ? Qt.alpha(card.tokens.cyan, 0.12)
          : sessionMouse.containsMouse ? Qt.alpha(card.tokens.text, 0.05)
          : "transparent"
        border.width: sessionList.currentIndex === index ? 1 : 0
        border.color: Qt.alpha(card.tokens.cyan, 0.6)

        Column {
          anchors {
            left: parent.left
            right: parent.right
            leftMargin: 16
            rightMargin: 16
            verticalCenter: parent.verticalCenter
          }
          spacing: 2

          Text {
            width: parent.width
            text: model.name
            color: card.tokens.text
            elide: Text.ElideRight
            font {
              family: card.tokens.font
              pixelSize: card.tokens.bodySize
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
              pixelSize: card.tokens.captionSize
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
