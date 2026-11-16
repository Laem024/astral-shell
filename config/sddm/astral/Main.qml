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
  readonly property bool wide: root.width / Math.max(0.1, theme.scale) >= 1000
  readonly property bool showLayout: theme.showKeyboard && typeof keyboard !== "undefined"
    && keyboard.enabled && keyboard.layouts && keyboard.layouts.length > 0
  readonly property int layoutCount: root.showLayout ? keyboard.layouts.length : 0
  readonly property string layoutName: root.showLayout
    ? String(keyboard.layouts[Math.max(0, Math.min(keyboard.currentLayout, root.layoutCount - 1))].shortName || "").toUpperCase()
    : ""
  readonly property real fit: Math.min(root.width / 620, root.height / 960)
  readonly property real factor: Math.max(0.5, Math.min(2.0,
    root.height / 930, root.width / 500, root.fit * theme.scale))
  readonly property real chrome: Math.max(1, Math.min(root.factor, 1.35))

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
      NumberAnimation { duration: theme.animations ? 320 : 0 }
    }
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

      Column {
        anchors.centerIn: parent
        width: theme.panelWidth
        spacing: root.wide ? 38 : 30

        Components.ClockBlock {
          width: parent.width
          tokens: theme
          dateTime: root.now
        }

        Loader {
          id: loginLoader
          width: parent.width
          active: root.active
          sourceComponent: loginComponent
          onLoaded: item.focusPassword()
        }
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
      NumberAnimation { duration: theme.animations ? 320 : 0 }
    }

    onActivate: root.activateScreen()
  }

  Item {
    anchors {
      left: parent.left
      right: parent.right
      top: parent.top
      leftMargin: 36 * root.chrome
      rightMargin: 36 * root.chrome
      topMargin: 32 * root.chrome
    }
    height: 22 * root.chrome

    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 18 * root.chrome

      Item {
        width: Math.round(16 * root.chrome)
        height: Math.round(22 * root.chrome)

        Text {
          anchors.centerIn: parent
          text: "✦"
          color: theme.cyan
          font.pixelSize: Math.round(15 * root.chrome)
        }
      }

      Text {
        text: "A S T R A L"
        height: Math.round(22 * root.chrome)
        verticalAlignment: Text.AlignVCenter
        color: theme.text
        font {
          family: theme.mono
          pixelSize: Math.round(10 * root.chrome)
          letterSpacing: 1
        }
      }

      Text {
        text: "S E C U R E   G R E E T E R"
        height: Math.round(22 * root.chrome)
        verticalAlignment: Text.AlignVCenter
        color: theme.muted
        font {
          family: theme.mono
          pixelSize: Math.round(9 * root.chrome)
          letterSpacing: 0.8
        }
      }
    }

    Row {
      anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
      }
      spacing: 16 * root.chrome

      Text {
        visible: theme.showHostname && sddm.hostName.length > 0
        text: sddm.hostName
        height: Math.round(22 * root.chrome)
        verticalAlignment: Text.AlignVCenter
        color: theme.muted
        font {
          family: theme.mono
          pixelSize: Math.round(9 * root.chrome)
          letterSpacing: 0.8
        }
      }

      Item {
        visible: root.showLayout && theme.showHostname && sddm.hostName.length > 0
        width: 1
        height: Math.round(22 * root.chrome)

        Rectangle {
          anchors.centerIn: parent
          width: 1
          height: Math.round(10 * root.chrome)
          color: theme.glassLine
        }
      }

      Text {
        visible: root.showLayout
        text: root.layoutName
        height: Math.round(22 * root.chrome)
        verticalAlignment: Text.AlignVCenter
        color: layoutMouse.containsMouse && root.layoutCount > 1 ? theme.cyan : theme.muted
        font {
          family: theme.mono
          pixelSize: Math.round(9 * root.chrome)
          letterSpacing: 0.8
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

  Text {
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom: parent.bottom
      bottomMargin: 26 * root.chrome
    }
    text: "A S T R A L   S H E L L   ·   S D D M"
    color: theme.muted
    opacity: 0.5
    font {
      family: theme.mono
      pixelSize: Math.round(8 * root.chrome)
      letterSpacing: 2
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
      width: root.themeTokens.panelWidth
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
