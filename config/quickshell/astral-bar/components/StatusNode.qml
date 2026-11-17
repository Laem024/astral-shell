pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "../../common" as Design

Item {
  id: root
  required property Design.Theme tokens
  required property string kind
  objectName: kind
  readonly property bool hovered: hover.hovered
  property bool vertical: false
  property bool compact: false
  property string label: ""
  property string detail: label
  property real level: 1
  property string networkState: "wifi"
  property color accent: tokens.cyan
  property bool warningEnabled: true
  property bool externalPower: false
  readonly property bool warning: warningEnabled && kind === "battery" && level >= 0 && level < 0.2
  readonly property bool hasValue: !compact && (kind === "audio" || kind === "battery")
  readonly property bool unread: kind === "notifications" && level > 0
  // Reserve accent color for actionable states rather than tinting every control.
  property color ink: warning ? tokens.alert
    : kind === "network" && ["off", "disconnected", "unavailable"].includes(networkState) ? tokens.muted
    : hovered ? tokens.cyan : tokens.text
  Behavior on ink { ColorAnimation { duration: root.tokens.hoverDuration } }
  signal activated()
  signal summaryActivated()
  implicitWidth: vertical ? 44 : hasValue ? 70 : unread && !compact ? 58 : 36
  implicitHeight: vertical && hasValue ? 52 : 36
  Accessible.name: detail
  Accessible.role: Accessible.Button
  activeFocusOnTab: true
  Accessible.onPressAction: root.activated()
  Keys.onSpacePressed: root.activated()
  Keys.onReturnPressed: root.activated()
  Keys.onEnterPressed: root.activated()
  ToolTip.visible: hovered
  ToolTip.text: detail
  ToolTip.delay: 650

  BarTile {
    anchors.fill: parent
    tokens: root.tokens
    accent: root.warning ? root.tokens.alert : root.tokens.cyan
    hovered: root.hovered
    focused: root.activeFocus
  }
  Item {
    id: content
    width: root.vertical ? root.width : glyph.width + (valueLabel.visible ? 7 + valueLabel.width : 0)
      + (badge.visible ? 5 + badge.width : 0)
    height: root.vertical && root.hasValue ? 42 : 20
    anchors.centerIn: parent
    StatusGlyph {
      id: glyph
      width: 20; height: 20
      x: root.vertical ? (parent.width - width) / 2 : 0
      y: 0
      ink: root.ink
      kind: root.kind === "network" ? root.networkState : root.kind
      muted: root.kind === "audio" && root.level <= 0
      level: root.level
      charging: root.externalPower
    }
    Text {
      id: valueLabel
      visible: root.hasValue
      x: root.vertical ? (parent.width - width) / 2 : glyph.width + 7
      y: root.vertical ? 25 : (20 - height) / 2
      text: root.label
      color: root.ink
      font { family: root.tokens.font; pixelSize: 12; weight: Font.DemiBold }
      Accessible.ignored: true
    }
    Rectangle {
      id: badge
      visible: root.unread && !root.vertical && !root.compact
      x: glyph.width + 5
      anchors.verticalCenter: glyph.verticalCenter
      width: Math.max(18, badgeText.implicitWidth + 8); height: 18; radius: 9
      color: Qt.alpha(root.tokens.cyan, 0.16)
      Text {
        id: badgeText
        anchors.centerIn: parent
        text: root.level > 99 ? "99+" : String(root.level)
        color: root.tokens.cyan
        font { family: root.tokens.font; pixelSize: 10; weight: Font.Bold }
        Accessible.ignored: true
      }
    }
    Rectangle {
      visible: root.unread && !badge.visible
      x: glyph.x + 16; y: 0
      width: 5; height: 5; radius: 2.5
      color: root.tokens.cyan
    }
  }
  HoverHandler { id: hover }
  TapHandler {
    onTapped: event => {
      const point = root.mapToItem(badge, event.position.x, event.position.y);
      if (badge.visible && point.x >= 0 && point.x <= badge.width && point.y >= 0 && point.y <= badge.height)
        root.summaryActivated();
      else root.activated();
    }
  }
}
