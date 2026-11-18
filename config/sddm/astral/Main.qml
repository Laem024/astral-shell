import QtQuick
import QtQuick.Window
import "design" as Design
import "components" as Components

Rectangle {
  id: root

  property date now: new Date()
  property var themeTokens: theme
  readonly property string screenName: Screen.name
  property var selectedUser: ({ name: "", realName: "", icon: "", needsPassword: true })
  property var selectedSession: ({ name: "", comment: "" })
  property int userIndex: userModel.lastIndex
  property int sessionIndex: sessionModel.lastIndex
  property bool busy: false
  property bool error: false
  property string message: ""
  property real entrance: 0

  readonly property bool primaryMode: theme.activationMode === "primary"
  readonly property bool active: root.primaryMode ? primaryScreen : Window.active
  readonly property bool canLogin: selectedUser.name !== "" && sessionIndex >= 0 && sessionProbe.count > 0
  readonly property bool showLayout: theme.showKeyboard && typeof keyboard !== "undefined"
    && keyboard.enabled && keyboard.layouts && keyboard.layouts.length > 0
  readonly property int layoutCount: root.showLayout ? keyboard.layouts.length : 0
  readonly property string layoutName: root.showLayout
    ? String(keyboard.layouts[Math.max(0, Math.min(keyboard.currentLayout, root.layoutCount - 1))].shortName || "").toUpperCase()
    : ""
  readonly property bool compact: width < 1000 || height < 650 || width / factor < 1000
  // The layout is authored on a 1280x800 canvas and scaled to the screen.
  readonly property real fit: Math.min(root.width / 1280, root.height / 800)
  readonly property real factor: Math.max(0.5, Math.min(2.0,
    (root.height - 120) / 520,
    (root.width - 48) / theme.panelWidth,
    theme.scale * Math.max(0.6, Math.min(1.25, root.fit))))
  readonly property real chrome: Math.max(1, Math.min(root.factor, 1.25))

  color: theme.background

  Design.Theme {
    id: theme
    values: config
  }

  Components.Backdrop {
    anchors.fill: parent
    tokens: theme
  }

  Components.Starfield {
    anchors.fill: parent
    tokens: theme
    seedName: root.screenName
  }

  Rectangle {
    anchors.fill: parent
    color: theme.background
    opacity: root.active ? 0 : theme.inactiveDim

    Behavior on opacity {
      NumberAnimation { duration: theme.entryDuration }
    }
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: 12 * root.chrome
    radius: 24 * root.chrome
    color: "transparent"
    border.color: Qt.alpha(theme.text, 0.16)
  }

  Item {
    id: activeContent
    anchors.fill: parent
    visible: root.active
    opacity: root.entrance

    Item {
      id: canvas
      anchors.centerIn: parent
      width: root.width / root.factor
      height: root.height / root.factor
      scale: root.factor * (0.985 + 0.015 * root.entrance)
      transform: Translate { y: (1 - root.entrance) * 16 }

      Rectangle {
        visible: !root.compact
        x: parent.width - theme.panelWidth - 112
        y: 88
        width: theme.panelWidth + 48
        height: parent.height - 176
        radius: theme.panelRadius + 12
        color: Qt.alpha(theme.background, 0.48)
        border.color: theme.border
      }

      Column {
        id: mainClock
        x: root.compact ? (parent.width - width) / 2 : 88
        y: root.compact ? Math.max(64, (parent.height - loginLoader.height - height - 24) / 2) : (parent.height - height) / 2
        width: Math.min(theme.panelWidth, parent.width - 48)
        spacing: root.compact ? 8 : 28

        Text {
          visible: !root.compact
          text: "YOUR SPACE. YOUR ORBIT."
          color: theme.cyan
          font { family: theme.mono; pixelSize: 11; letterSpacing: 2 }
        }

        Components.ClockBlock {
          width: parent.width
          compact: root.compact
          centered: root.compact
          tokens: theme
          dateTime: root.now
        }

        Rectangle {
          visible: !root.compact
          width: 48
          height: 2
          color: theme.cyan
        }

        Text {
          visible: !root.compact
          width: parent.width
          text: "Welcome back."
          color: theme.text
          font { family: theme.font; pixelSize: 34; weight: Font.Light }
        }

        Text {
          visible: !root.compact
          width: parent.width
          text: "A little focus. A world of possibilities."
          wrapMode: Text.WordWrap
          color: theme.muted
          font { family: theme.font; pixelSize: 14 }
        }
      }

      Loader {
        id: loginLoader
        x: root.compact ? (parent.width - width) / 2 : parent.width - width - 88
        y: root.compact ? mainClock.y + mainClock.height + 24 : (parent.height - height) / 2
        width: Math.min(theme.panelWidth, parent.width - 48)
        active: root.active
        sourceComponent: loginComponent
        onLoaded: item.focusPassword()
      }
    }

    Row {
      id: powerRow
      x: root.compact ? (parent.width - width) / 2 : parent.width - theme.panelWidth * root.factor - 88 * root.factor
      anchors {
        bottom: parent.bottom
        bottomMargin: 24 * root.chrome
      }
      spacing: 8 * root.chrome

      Components.AstralButton {
        visible: theme.showPower && sddm.canPowerOff
        height: 36 * root.chrome
        tokens: theme
        label: "Power off"
        armedLabel: "Confirm power off"
        tone: "alert"
        confirm: true
        onClicked: sddm.powerOff()
      }

      Components.AstralButton {
        visible: theme.showPower && sddm.canReboot
        height: 36 * root.chrome
        tokens: theme
        label: "Restart"
        armedLabel: "Confirm restart"
        tone: "alert"
        confirm: true
        onClicked: sddm.reboot()
      }

      Components.AstralButton {
        visible: theme.showPower && sddm.canSuspend
        height: 36 * root.chrome
        tokens: theme
        label: "Suspend"
        onClicked: sddm.suspend()
      }
    }
  }

  Components.InactiveView {
    anchors.fill: parent
    tokens: theme
    dateTime: root.now
    hostname: sddm.hostName
    clickable: !root.primaryMode
    factor: root.factor
    opacity: root.active ? 0 : 1
    visible: opacity > 0.01

    Behavior on opacity {
      NumberAnimation { duration: theme.entryDuration }
    }

    onActivate: root.activateScreen()
  }

  Item {
    id: topBar
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      leftMargin: 24 * root.chrome
      rightMargin: 24 * root.chrome
      topMargin: 20 * root.chrome
    }
    height: Math.round(24 * root.chrome)

    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8 * root.chrome

      Text {
        text: "✦"
        height: topBar.height
        verticalAlignment: Text.AlignVCenter
        color: theme.cyan
        font.pixelSize: Math.round(12 * root.chrome)
      }

      Text {
        text: "ASTRAL"
        height: topBar.height
        verticalAlignment: Text.AlignVCenter
        color: theme.text
        font {
          family: theme.mono
          pixelSize: Math.round(11 * root.chrome)
          letterSpacing: 3
        }
      }
    }

    Row {
      anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
      }
      spacing: 8 * root.chrome

      Text {
        visible: theme.showHostname && sddm.hostName.length > 0
        text: sddm.hostName
        height: topBar.height
        verticalAlignment: Text.AlignVCenter
        color: theme.muted
        font {
          family: theme.mono
          pixelSize: Math.round(10 * root.chrome)
          letterSpacing: 1
        }
      }

      Text {
        visible: root.showLayout && theme.showHostname && sddm.hostName.length > 0
        text: "·"
        height: topBar.height
        verticalAlignment: Text.AlignVCenter
        color: theme.muted
        font.pixelSize: Math.round(10 * root.chrome)
      }

      Text {
        visible: root.showLayout
        text: root.layoutName
        height: topBar.height
        verticalAlignment: Text.AlignVCenter
        color: layoutMouse.containsMouse && root.layoutCount > 1 ? theme.cyan : theme.muted
        font {
          family: theme.mono
          pixelSize: Math.round(10 * root.chrome)
          letterSpacing: 1
        }

        MouseArea {
          id: layoutMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: root.layoutCount > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: root.cycleLayout()
        }
      }
    }
  }

  Repeater {
    id: userProbe
    model: userModel

    delegate: Item {
      id: userProbeItem
      visible: false

      readonly property bool selected: index === root.userIndex

      function publish() {
        if (!selected)
          return
        root.selectedUser = {
          name: model.name || "",
          realName: model.realName || "",
          icon: model.icon || "",
          needsPassword: model.needsPassword !== false
        }
      }

      Component.onCompleted: publish()
      onSelectedChanged: publish()
    }
  }

  Repeater {
    id: sessionProbe
    model: sessionModel

    delegate: Item {
      id: sessionProbeItem
      visible: false

      readonly property bool selected: index === root.sessionIndex

      function publish() {
        if (!selected)
          return
        root.selectedSession = {
          name: model.name || "",
          comment: model.comment || ""
        }
      }

      Component.onCompleted: publish()
      onSelectedChanged: publish()
    }
  }

  Connections {
    target: userProbe
    function onCountChanged() {
      if (root.userIndex < 0 || root.userIndex >= userProbe.count)
        root.userIndex = Math.max(0, userProbe.count - 1)
    }
  }

  Connections {
    target: sessionProbe
    function onCountChanged() {
      if (root.sessionIndex < 0 || root.sessionIndex >= sessionProbe.count)
        root.sessionIndex = Math.max(0, sessionProbe.count - 1)
    }
  }

  Connections {
    target: sddm

    function onLoginFailed() {
      root.busy = false
      root.error = true
      root.message = "Incorrect password. Try again."
      if (loginLoader.item) {
        loginLoader.item.clearPassword()
        loginLoader.item.shake()
        loginLoader.item.focusPassword()
      }
    }

    function onLoginSucceeded() {
      root.busy = false
      root.error = false
      root.message = "Welcome"
    }

    function onInformationMessage(message) {
      root.busy = false
      root.error = true
      root.message = message
      if (loginLoader.item) {
        loginLoader.item.clearPassword()
        loginLoader.item.focusPassword()
      }
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  NumberAnimation {
    id: entranceAnimation
    target: root
    property: "entrance"
    from: 0
    to: 1
    duration: theme.entryDuration
    easing.type: Easing.OutCubic
  }

  Component {
    id: loginComponent

    Components.LoginCard {
      width: loginLoader.width
      tokens: root.themeTokens
      user: root.selectedUser
      userIndex: root.userIndex
      userCount: userProbe.count
      session: root.selectedSession
      sessionIndex: root.sessionIndex
      sessionCount: sessionProbe.count
      busy: root.busy
      error: root.error
      message: root.message

      onSubmitted: password => root.submit(password)

      onUserSelected: index => {
        root.userIndex = index
        root.error = false
        root.message = ""
      }

      onSessionSelected: index => root.sessionIndex = index
    }
  }

  function activateScreen() {
    if (root.primaryMode || root.active)
      return
    if (Window.window)
      Window.window.requestActivate()
  }

  function cycleLayout() {
    if (!root.showLayout || root.layoutCount < 2)
      return
    keyboard.currentLayout = (keyboard.currentLayout + 1) % root.layoutCount
  }

  function submit(password) {
    if (!root.active || root.busy || !root.canLogin)
      return
    if (root.selectedUser.needsPassword !== false && password.length === 0)
      return
    root.busy = true
    root.error = false
    root.message = ""
    sddm.login(root.selectedUser.name, password, root.sessionIndex)
  }

  onActiveChanged: {
    if (root.active) {
      if (theme.animations)
        entranceAnimation.restart()
      else
        root.entrance = 1
      Qt.callLater(() => { if (loginLoader.item) loginLoader.item.focusPassword() })
    } else {
      root.entrance = 0
      if (loginLoader.item)
        loginLoader.item.clearPassword()
    }
  }

  Component.onCompleted: {
    if (root.active) {
      if (theme.animations)
        entranceAnimation.start()
      else
        root.entrance = 1
      Qt.callLater(() => { if (loginLoader.item) loginLoader.item.focusPassword() })
    }
  }
}
