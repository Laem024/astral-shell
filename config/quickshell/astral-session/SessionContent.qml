pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Logic.js" as Logic
import "../common" as Common

FocusScope {
  id: root
  required property var tokens
  property bool active: false
  readonly property var actions: Logic.actions.filter(action => Common.SessionActions.available(action.id))
  readonly property bool busy: Common.SessionActions.pending
  readonly property bool failed: Common.SessionActions.error !== ""
  readonly property bool compact: width < 760 || height < 470
  readonly property string subtitle: root.busy ? "Working…"
    : root.failed ? Common.SessionActions.error
    : "Choose an action. Destructive ones need a short hold."
  readonly property color subtitleColor: root.busy ? root.tokens.gold
    : root.failed ? root.tokens.alert : root.tokens.muted
  property string holding: ""
  property real holdProgress: 0
  property int focusIndex: 0
  signal closeRequested()

  onActiveChanged: {
    if (!active) cancelHold();
    else Qt.callLater(() => { if (root.active) root.forceActiveFocus(); });
  }
  onActiveFocusChanged: if (!activeFocus) cancelHold()

  function reset() {
    cancelHold();
    Common.SessionActions.error = "";
    if (root.active) root.forceActiveFocus();
  }
  function trigger(id) {
    if (Common.SessionActions.pending || Common.SessionActions.blocked) return;
    cancelHold();
    Common.SessionActions.perform(id);
  }
  function startHold(id) {
    if (Common.SessionActions.pending || Common.SessionActions.blocked) return;
    if (!Logic.requiresHold(id)) { trigger(id); return; }
    root.holding = id;
    root.holdProgress = 0;
    holdAnimation.restart();
    holdTimer.restart();
  }
  function cancelHold() {
    if (root.holding === "" && !holdTimer.running) return;
    root.holding = "";
    holdTimer.stop();
    holdAnimation.stop();
    root.holdProgress = 0;
  }
  function finishHold() {
    const id = root.holding;
    if (!id) return;
    root.holding = "";
    holdTimer.stop();
    holdAnimation.stop();
    root.holdProgress = 0;
    trigger(id);
  }
  function pressKey(text) {
    const id = Logic.shortcutAction(text);
    if (!id) return false;
    if (Logic.requiresHold(id)) startHold(id); else trigger(id);
    return true;
  }
  function releaseKey(text) {
    const id = Logic.shortcutAction(text);
    if (id && root.holding === id) { cancelHold(); return true; }
    return false;
  }
  function focusTile(index) {
    const count = root.actions.length;
    if (index < 0 || index >= count) return;
    root.focusIndex = index;
    const item = listRepeater.itemAt(index);
    if (item) item.forceActiveFocus();
  }

  Keys.onPressed: event => {
    if (event.key === Qt.Key_Escape) {
      if (root.holding !== "") root.cancelHold();
      else if (!Common.SessionActions.pending) root.closeRequested();
      event.accepted = true;
      return;
    }
    if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
      root.cancelHold();
      const count = root.actions.length;
      if (count === 0) return;
      const step = event.key === Qt.Key_Left || event.key === Qt.Key_Up ? -1 : 1;
      root.focusTile((root.focusIndex + step + count) % count);
      event.accepted = true;
      return;
    }
    if (event.isAutoRepeat) {
      if (root.holding !== "") event.accepted = true;
      return;
    }
    if (root.pressKey(event.text)) event.accepted = true;
  }
  Keys.onReleased: event => {
    if (event.isAutoRepeat) return;
    if (root.releaseKey(event.text)) event.accepted = true;
  }

  Timer {
    id: holdTimer
    interval: Logic.holdDuration
    onTriggered: root.finishHold()
  }
  NumberAnimation {
    id: holdAnimation
    target: root
    property: "holdProgress"
    from: 0
    to: 1
    duration: Logic.holdDuration
    easing.type: Easing.Linear
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: root.compact ? 18 : 28
    spacing: root.compact ? 10 : 14

    RowLayout {
      Layout.fillWidth: true
      spacing: root.compact ? 12 : 16

      Rectangle {
        Layout.preferredWidth: root.compact ? 46 : 54
        Layout.preferredHeight: Layout.preferredWidth
        Layout.alignment: Qt.AlignTop
        radius: width / 2
        color: Qt.alpha(root.tokens.cyan, 0.08)
        border.color: Qt.alpha(root.tokens.cyan, 0.24)
        Text {
          anchors.centerIn: parent
          text: "✦"
          color: root.tokens.cyan
          font { family: root.tokens.mono; pixelSize: root.compact ? 23 : 27 }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2
        Text {
          text: "ASTRAL"
          color: root.tokens.cyan
          font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 1.8 }
        }
        Text {
          Layout.fillWidth: true
          text: "End session"
          color: root.tokens.text
          elide: Text.ElideRight
          font { family: root.tokens.font; pixelSize: root.compact ? 24 : 30; weight: Font.DemiBold }
        }
        Text {
          Layout.fillWidth: true
          Layout.topMargin: 1
          text: root.subtitle
          textFormat: Text.PlainText
          color: root.subtitleColor
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          font { family: root.tokens.font; pixelSize: root.compact ? 11 : 12 }
        }
      }

      Button {
        id: closeButton
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        Accessible.name: "Close session menu"
        onClicked: root.closeRequested()
        contentItem: Text {
          text: "×"
          color: root.tokens.muted
          font.pixelSize: 23
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
          radius: 16
          color: closeButton.hovered ? Qt.alpha(root.tokens.muted, 0.12) : "transparent"
          border.color: closeButton.activeFocus ? root.tokens.cyan : "transparent"
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 1
      color: root.tokens.border
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: root.compact ? 4 : 6

      Repeater {
        id: listRepeater
        model: root.actions
        delegate: ActionTile {
          required property var modelData
          required property int index
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.minimumHeight: 46
          Layout.preferredHeight: root.compact ? 54 : 62
          compact: root.compact
          tokens: root.tokens
          actionData: modelData
          enabled: !Common.SessionActions.pending
          opacity: enabled ? 1 : 0.45
          holding: root.holding === modelData.id
          progress: root.holding === modelData.id ? root.holdProgress : 0
          onActiveFocusChanged: if (activeFocus) root.focusIndex = index
          onHoldStarted: root.startHold(modelData.id)
          onHoldEnded: root.cancelHold()
          onActivated: root.trigger(modelData.id)
        }
      }
    }
  }
}
