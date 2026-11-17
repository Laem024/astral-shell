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
  readonly property var actions: ["lock", "logout", "suspend", "reboot", "poweroff"].map(id => Logic.byId(id)).filter(action => Common.SessionActions.available(action.id))
  readonly property bool busy: Common.SessionActions.pending
  readonly property bool failed: Common.SessionActions.error !== ""
  readonly property bool compact: width < 700
  readonly property int actionColumns: width >= 700 ? 5 : width >= 420 ? 3 : 2
  readonly property string subtitle: root.busy ? "Working…"
    : root.failed ? Common.SessionActions.error
    : "Lock, rest, or end your session."
  readonly property color subtitleColor: root.busy ? root.tokens.gold
    : root.failed ? root.tokens.alert : root.tokens.muted
  property string holding: ""
  property real holdProgress: 0
  property int focusIndex: 0
  implicitHeight: contentLayout.implicitHeight + 2 * (root.compact ? 16 : 24)
  signal closeRequested()

  onActiveChanged: {
    if (!active) cancelHold();
    else Qt.callLater(() => { if (root.active) root.focusTile(0); });
  }
  onActiveFocusChanged: if (!activeFocus) cancelHold()

  function reset() {
    cancelHold();
    Common.SessionActions.error = "";
    if (root.active) root.focusTile(0);
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
    if (item) {
      item.forceActiveFocus();
      revealTile(item);
    }
  }

  function revealTile(item) {
    if (item.y < actionScroll.contentY) actionScroll.contentY = item.y;
    else if (item.y + item.height > actionScroll.contentY + actionScroll.height)
      actionScroll.contentY = item.y + item.height - actionScroll.height;
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
      const step = event.key === Qt.Key_Up ? -root.actionColumns
        : event.key === Qt.Key_Down ? root.actionColumns : event.key === Qt.Key_Left ? -1 : 1;
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
    id: contentLayout
    anchors.fill: parent
    anchors.margins: root.compact ? 16 : 24
    spacing: root.compact ? 12 : 16

    RowLayout {
      Layout.fillWidth: true
      spacing: 16

      Rectangle {
        Layout.preferredWidth: root.compact ? 44 : 48
        Layout.preferredHeight: Layout.preferredWidth
        Layout.alignment: Qt.AlignTop
        radius: width / 2
        color: Qt.alpha(root.tokens.cyan, 0.1)
        border.width: 1
        border.color: Qt.alpha(root.tokens.cyan, 0.3)
        Text {
          anchors.centerIn: parent
          text: "✦"
          color: root.tokens.cyan
          font { family: root.tokens.mono; pixelSize: root.compact ? 20 : 22 }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2
        Text {
          text: "ASTRAL"
          color: root.tokens.cyan
          font { family: root.tokens.mono; pixelSize: 10; letterSpacing: 1.6 }
        }
        Text {
          Layout.fillWidth: true
          text: "Session"
          color: root.tokens.text
          elide: Text.ElideRight
          font { family: root.tokens.font; pixelSize: root.compact ? 20 : 22; weight: Font.DemiBold }
        }
        Text {
          Layout.fillWidth: true
          Layout.topMargin: 2
          text: root.subtitle
          textFormat: Text.PlainText
          color: root.subtitleColor
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          font { family: root.tokens.font; pixelSize: 12 }
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
          color: closeButton.hovered ? root.tokens.text : root.tokens.muted
          font { family: root.tokens.font; pixelSize: 20 }
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
          radius: root.tokens.controlRadius
          color: closeButton.down ? Qt.alpha(root.tokens.muted, 0.18)
            : closeButton.hovered ? Qt.alpha(root.tokens.muted, 0.1)
            : "transparent"
          border.width: closeButton.visualFocus ? 2 : 0
          border.color: root.tokens.cyan
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 1
      color: root.tokens.hairline
    }

    Flickable {
      id: actionScroll
      objectName: "sessionActionScroll"
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 0
      Layout.preferredHeight: actionRow.implicitHeight
      contentWidth: width
      contentHeight: actionRow.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      GridLayout {
        id: actionRow
        width: actionScroll.width
        columns: root.actionColumns
        columnSpacing: 10
        rowSpacing: 10
        Repeater {
          id: listRepeater
          model: root.actions
          delegate: ActionTile {
            id: actionTile
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredHeight: root.compact ? 158 : 172
            compact: root.compact
            tokens: root.tokens
            actionData: modelData
            enabled: !Common.SessionActions.pending
            opacity: enabled ? 1 : 0.45
            holding: root.holding === modelData.id
            progress: root.holding === modelData.id ? root.holdProgress : 0
            onActiveFocusChanged: if (activeFocus) {
              root.focusIndex = index;
              root.revealTile(actionTile);
            }
            onHoldStarted: root.startHold(modelData.id)
            onHoldEnded: root.cancelHold()
            onActivated: root.trigger(modelData.id)
          }
        }
      }
    }
    Text {
      Layout.fillWidth: true
      text: root.holding ? "Keep holding to confirm" : "Press L or S     ·     Hold O, R or P to confirm     ·     Esc  Close"
      color: root.holding ? root.tokens.gold : root.tokens.muted
      font { family: root.tokens.font; pixelSize: 10 }
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
    }
  }
}
