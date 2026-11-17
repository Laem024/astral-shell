import QtQuick
import QtQuick.Layouts
import "../common" as Design
import "components" as Components
import "modules" as Modules
import "data" as Data

Item {
  id: root
  objectName: "barContent"
  required property var settings
  required property Design.Theme tokens
  required property var navigation
  signal launcherRequested()
  property var monitor: null
  property var nativeWindow: null
  property bool vertical: false
  onVerticalChanged: {
    viewport.cancelFlick();
    viewport.contentX = 0;
    viewport.contentY = 0;
  }
  readonly property bool compact: vertical || width < 1150
  // Vertical plates keep a fixed visual width so scaling never turns their
  // side margins into the dominant gap. Along the cross axis both orientations
  // leave the same 6px between a plate and the bar edge: horizontal plates are
  // capped at viewport height - 4, so vertical plates are 12px narrower than
  // the bar's cross axis and the side margins match the horizontal unit inset.
  readonly property real verticalPlateWidth: Math.min(viewport.width, tokens.verticalSize - 12)
  // Reserve one special slot even while closed, keeping vertical geometry stable.
  readonly property bool minimal: vertical
    ? height < 780 + Math.max(0, Design.SettingsData.value.workspaceCount - 5) * 26
      + 36
    : width < 850 || width - 2 * tokens.inset < 2 * Math.max(minimumGroupWidth(startGroup), labeledEndMinimum())
      + (shown.workspaces ? Design.SettingsData.value.workspaceCount * 32 + 42 + 2 * tokens.section : tokens.section)
  // Only minimum child sizes constrain the symmetric side groups. Preferred
  // media width must remain negotiable, otherwise it forces horizontal scroll.
  function minimumGroupWidth(group) {
    if (!group) return 0;
    const children = group.children.filter(child => child.visible);
    return children.reduce((sum, child) => sum
      + (child.Layout.minimumWidth >= 0 ? child.Layout.minimumWidth : child.implicitWidth)
      + child.Layout.leftMargin + child.Layout.rightMargin, 0)
      + Math.max(0, children.length - 1) * group.columnSpacing;
  }
  function labeledEndMinimum() {
    const statusCount = ["network", "audio", "battery", "notifications"].filter(key => shown[key]).length;
    const modules = 1 + statusCount + Number(!!shown.music) + Number(!!shown.tray);
    // Labeled status nodes are 84px; compact media keeps its 124px transport.
    return 40 + statusCount * 84 + Number(!!shown.music) * (124 + 10) + Number(!!shown.tray) * 40
      + (modules + Number(!!shown.music)) * tokens.gap;
  }
  readonly property var shown: settings.value.modules
  Data.WorkspaceData {
    id: workspaceData
    screen: root.monitor
    count: Design.SettingsData.value.workspaceCount
  }
  property bool entered: false
  opacity: entered || !settings.value.animations ? 1 : 0
  Component.onCompleted: entered = true
  Behavior on opacity {
    enabled: root.settings.value.animations
    NumberAnimation { duration: root.tokens.entryDuration }
  }
  Components.AstralSurface { anchors.fill: parent; tokens: root.tokens; vertical: root.vertical; position: root.settings.value.position }
  // Vertical content fits the available height, including a visible special.
  // Horizontal bars retain their scroll fallback on narrow screens.
  Flickable {
    id: viewport
    objectName: "moduleViewport"
    anchors.fill: parent
    anchors.leftMargin: root.vertical ? root.tokens.unit : root.tokens.inset
    anchors.rightMargin: root.vertical ? root.tokens.unit : root.tokens.inset
    anchors.topMargin: root.vertical ? root.tokens.padding : root.tokens.unit
    anchors.bottomMargin: root.vertical ? root.tokens.padding : root.tokens.unit
    contentWidth: root.vertical ? width : Math.max(width, composition.implicitWidth)
    contentHeight: height
    interactive: !root.vertical
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: root.vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
    Rectangle {
      objectName: "startPlate"
      x: root.vertical ? (viewport.width - root.verticalPlateWidth) / 2 : startGroup.x * composition.scale
      y: root.vertical ? startGroup.y * composition.scale : (composition.height - height) / 2
      scale: composition.scale
      transformOrigin: Item.TopLeft
      width: root.vertical ? root.verticalPlateWidth / composition.scale : startGroup.width
      height: root.vertical ? startGroup.height : Math.max(0, Math.min(composition.height - 4, Math.max(startGroup.height, endGroup.height) + 6))
      visible: (root.shown.logo || root.shown.clock || (root.shown.window && (root.vertical || !root.compact)))
      radius: root.tokens.rowRadius; color: root.tokens.raised; border.color: root.tokens.hairline
    }
    Rectangle {
      objectName: "endPlate"
      x: root.vertical ? (viewport.width - root.verticalPlateWidth) / 2 : endGroup.x * composition.scale
      y: root.vertical ? endGroup.y * composition.scale : (composition.height - height) / 2
      scale: composition.scale
      transformOrigin: Item.TopLeft
      width: root.vertical ? root.verticalPlateWidth / composition.scale : endGroup.width
      height: root.vertical ? endGroup.height : Math.max(0, Math.min(composition.height - 4, Math.max(startGroup.height, endGroup.height) + 6))
      visible: true
      radius: root.tokens.rowRadius; color: root.tokens.raised; border.color: root.tokens.hairline
    }
    GridLayout {
      id: composition
      objectName: "composition"
      readonly property real sideMinimum: Math.max(root.minimumGroupWidth(startGroup), root.minimumGroupWidth(endGroup))
      readonly property real sideExtent: Math.max(sideMinimum, (width - (root.shown.workspaces ? centerWorkspaces.implicitWidth + 2 * root.tokens.section : root.tokens.section)) / 2)
      readonly property real sideHeight: Math.max(startGroup.implicitHeight, endGroup.implicitHeight)
      readonly property int visibleGroups: Number(startGroup.visible) + Number(root.shown.workspaces) + Number(endGroup.visible)
      readonly property real minimumVerticalHeight: (startGroup.visible ? sideHeight : 0)
        + (endGroup.visible ? sideHeight : 0)
        + (root.shown.workspaces ? workspaceContainer.implicitHeight : 0)
        + Math.max(0, visibleGroups - 1) * rowSpacing
      scale: root.vertical ? Math.min(1, viewport.height / Math.max(1, minimumVerticalHeight)) : 1
      transformOrigin: Item.TopLeft
      width: viewport.contentWidth / scale
      height: viewport.contentHeight / scale
      columns: root.vertical ? 1 : 3
      columnSpacing: root.tokens.section
      rowSpacing: root.tokens.gap
      GridLayout {
        id: startGroup
        objectName: "startGroup"
        visible: !root.vertical || root.shown.logo || root.shown.clock || (root.shown.window && (root.vertical || !root.compact))
        Layout.minimumWidth: root.vertical ? 60 : composition.sideMinimum
        Layout.maximumWidth: root.vertical ? 60 : composition.sideExtent
        Layout.fillWidth: !root.vertical
        Layout.fillHeight: false
        Layout.preferredWidth: root.vertical ? 60 : composition.sideMinimum
        Layout.minimumHeight: root.vertical ? composition.sideHeight : 0
        Layout.maximumHeight: root.vertical ? composition.sideHeight : Infinity
        Layout.preferredHeight: root.vertical ? composition.sideHeight : -1
        Layout.alignment: root.vertical ? Qt.AlignHCenter | Qt.AlignTop : Qt.AlignVCenter
        columns: root.vertical ? 1 : 7
        columnSpacing: 12
        rowSpacing: root.vertical ? 8 : 12
        Item { visible: !root.vertical; implicitWidth: 0; implicitHeight: 1 }
        Modules.LogoModule {
          id: logo
          onActivated: root.launcherRequested()
          Layout.bottomMargin: root.vertical ? (clock.visible || focus.visible ? -1 : 12) : 0
          Layout.topMargin: root.vertical ? 12 : 0
          Layout.maximumWidth: implicitWidth
          visible: root.shown.logo
          Layout.alignment: Qt.AlignHCenter
          tokens: root.tokens
          logoGlyph: root.settings.value.logo.glyph
          logoImage: root.settings.value.logo.image
        }
        Rectangle {
          objectName: "logoClockDivider"
          visible: clock.visible
          Layout.topMargin: root.vertical && !logo.visible ? 12 : 0
          implicitWidth: root.vertical ? 20 : 3
          implicitHeight: root.vertical ? 3 : 20
          Layout.alignment: Qt.AlignCenter
          color: root.tokens.border
        }
        Modules.ClockModule {
          id: clock
          Layout.bottomMargin: root.vertical && !focus.visible ? 12 : 0
          Layout.maximumWidth: implicitWidth
          visible: root.shown.clock
          Layout.alignment: Qt.AlignHCenter
          tokens: root.tokens
          offsetSeconds: Data.WeatherData.offsetFor(Data.ClockData.dateTime.getTime())
          onActivated: root.navigate("Weather & Calendar", clock)
          dateTime: Data.ClockData.dateTime
          vertical: root.vertical
        }
        Rectangle {
          objectName: "clockWindowDivider"
          visible: focus.visible
          Layout.topMargin: root.vertical && !logo.visible && !clock.visible ? 12 : 0
          implicitWidth: root.vertical ? 20 : 1
          implicitHeight: root.vertical ? 1 : 20
          Layout.alignment: Qt.AlignCenter
          color: root.tokens.border
        }
        Modules.WindowModule {
          id: focus
          Layout.bottomMargin: root.vertical ? 12 : 0
          Layout.minimumWidth: root.vertical ? implicitWidth : 80
          Layout.maximumWidth: root.vertical ? implicitWidth : Infinity
          Layout.fillWidth: !root.vertical
          Layout.fillHeight: root.vertical
          visible: root.shown.window && (root.vertical || !root.compact)
          Layout.alignment: Qt.AlignHCenter
          tokens: root.tokens
          vertical: root.vertical
          title: Data.WindowData.title
          available: Data.WindowData.available
          expanded: root.navigation.windowMenu && root.navigation.owner === root
          compact: root.compact
          onActivated: root.navigateWindowMenu(focus)
        }
        Item { visible: !root.vertical && !focus.visible; Layout.fillWidth: true }
      }
      Item {
        id: workspaceContainer
        visible: root.shown.workspaces
        implicitWidth: centerWorkspaces.implicitWidth
        implicitHeight: root.vertical ? centerWorkspaces.normalLength + 10 + centerWorkspaces.step : centerWorkspaces.implicitHeight
        Layout.fillHeight: root.vertical
        Layout.alignment: Qt.AlignCenter
      Modules.Workspaces {
        id: centerWorkspaces
        visible: root.shown.workspaces
        anchors.centerIn: parent
        // Keep normal positions fixed as the reserved special slot appears.
        anchors.verticalCenterOffset: root.vertical ? (implicitHeight - workspaceContainer.implicitHeight) / 2 : 0
        tokens: root.tokens
        spaces: workspaceData.workspaces
        specials: workspaceData.specials
        display: root.settings.value.workspaceDisplay
        count: Design.SettingsData.value.workspaceCount
        active: workspaceData.active
        activeSpecial: workspaceData.activeSpecial
        interactive: workspaceData.ready
        onSelected: workspace => workspaceData.activate(workspace)
        onSpecialSelected: name => workspaceData.closeSpecial(name)
        vertical: root.vertical
        compact: root.vertical || root.minimal
      }
      }
      GridLayout {
        id: endGroup
        objectName: "endGroup"
        visible: true
        Layout.minimumWidth: root.vertical ? 60 : composition.sideMinimum
        Layout.maximumWidth: root.vertical ? 60 : composition.sideExtent
        Layout.fillWidth: !root.vertical
        Layout.fillHeight: false
        Layout.preferredWidth: root.vertical ? 60 : composition.sideMinimum
        Layout.minimumHeight: root.vertical ? composition.sideHeight : 0
        Layout.maximumHeight: root.vertical ? composition.sideHeight : Infinity
        Layout.preferredHeight: root.vertical ? composition.sideHeight : -1
        Layout.alignment: root.vertical ? Qt.AlignHCenter | Qt.AlignBottom : Qt.AlignVCenter
        columns: root.vertical ? 1 : 9
        columnSpacing: root.minimal ? Math.max(3, root.tokens.gap / 2) : root.tokens.gap
        rowSpacing: root.vertical ? 6 : root.tokens.gap
        Item { visible: !root.vertical; Layout.fillWidth: true }
        Modules.MusicModule {
          id: music
          Layout.fillWidth: !root.vertical && !root.compact
          Layout.minimumWidth: root.vertical ? 48 : 124
          Layout.preferredWidth: root.vertical || root.compact ? music.implicitWidth
            : Math.max(340, Math.min(420, root.width * 0.2))
          Layout.maximumWidth: root.vertical || root.compact ? music.implicitWidth : 420
          Layout.topMargin: root.vertical && !(false) ? 12 : 0
          Layout.bottomMargin: 0
          visible: root.shown.music
          Layout.alignment: Qt.AlignHCenter
          tokens: root.tokens
          onActivated: root.navigate("Media", music)
          vertical: root.vertical
          compact: root.compact || (!root.vertical && width < 220)
        }
        Modules.CaptureModule {
          id: capture
          visible: root.shown.capture
          compact: root.minimal
          tokens: root.tokens
          vertical: root.vertical
          recording: Data.CaptureData.busy
          captureKind: Data.CaptureData.kind
          captureState: Data.CaptureData.state
          duration: Data.CaptureData.duration
          Layout.alignment: Qt.AlignCenter
          Layout.topMargin: root.vertical && !root.shown.music ? 12 : 0
          Layout.bottomMargin: root.vertical && !(root.shown.tray || root.shown.network || root.shown.audio || root.shown.battery || root.shown.notifications) ? 12 : 0
          onClicked: {
            if (recording) Data.CaptureData.stop();
            else root.navigate("Display", capture);
          }
        }
        Components.Constellation {
          visible: root.shown.music && !root.minimal
          Layout.alignment: Qt.AlignHCenter
          tokens: root.tokens
          vertical: root.vertical
        }
        Modules.TrayModule {
          id: tray
          Layout.topMargin: 0
          Layout.bottomMargin: 0
          visible: root.shown.tray
          Layout.alignment: Qt.AlignHCenter
          tokens: root.tokens
          panel: root
          navigation: root.navigation
          nativeWindow: root.nativeWindow
        }
        Modules.NetworkModule {
          id: networkNode
          Layout.topMargin: 0
          Layout.bottomMargin: 0
          visible: root.shown.network
          Layout.alignment: Qt.AlignHCenter
          tokens: root.tokens
          onActivated: root.navigate("Control Center", networkNode)
          connectionLabel: Data.SystemData.networkLabel
          connectionDetail: Data.SystemData.networkDetail
          connectionState: Data.SystemData.networkState
          strength: Data.SystemData.networkLevel
          vertical: root.vertical
          compact: root.minimal
        }
        Modules.AudioModule {
          id: audio
          Layout.topMargin: 0
          Layout.bottomMargin: 0
          visible: root.shown.audio
          Layout.alignment: Qt.AlignHCenter
          tokens: root.tokens
          onActivated: root.navigate("Sound", audio)
          volume: Data.SystemData.volume
          muted: Data.SystemData.muted
          audioDetail: Data.SystemData.audioDetail
          vertical: root.vertical
          compact: root.minimal
        }
        Modules.BatteryModule {
          id: battery
          Layout.topMargin: 0
          Layout.bottomMargin: 0
          visible: root.shown.battery
          Layout.alignment: Qt.AlignHCenter
          tokens: root.tokens
          onActivated: root.navigate("Power", battery)
          percent: Data.SystemData.batteryPercent
          externalPower: Data.SystemData.externalPower
          discharging: Data.SystemData.discharging
          batteryState: Data.SystemData.batteryState
          vertical: root.vertical
          compact: root.minimal
        }
        Modules.NotificationsModule {
          id: notifications
          Layout.topMargin: 0
          Layout.bottomMargin: root.vertical ? 12 : 0
          visible: root.shown.notifications
          Layout.alignment: Qt.AlignHCenter
          tokens: root.tokens
          onActivated: root.navigate("Notifications", notifications)
          onSummaryActivated: root.navigate("Notifications", notifications)
          count: Data.NotificationData.unread
          vertical: root.vertical
          compact: root.minimal
        }

      }
    }
  }
  function navigate(tab: string, control: Item): void {
    navigation.toggle(tab, root, control);
  }
  function navigateWindowMenu(control: Item): void {
    navigation.toggleWindowMenu(root, control);
  }
  Connections {
    target: focus
    // Hiding the module (for example on a narrow horizontal bar) must not
    // leave an orphaned menu anchored to a module outside the viewport.
    function onVisibleChanged(): void {
      if (!focus.visible && root.navigation.windowMenu && root.navigation.owner === root)
        root.navigation.close();
    }
  }
  // This visual layer has no input handlers; controls retain their own hit areas.
  readonly property Item hoveredSegment: {
    var modules = [clock, focus, music, capture, networkNode, audio, battery, notifications, tray];
    for (const module of modules)
      if (module.visible && module.hovered) return module;
    return null;
  }
  function syncIndicator(indicator: Components.HoverIndex, segment: Item): void {
    if (!segment || !segment.visible) { indicator.clear(); return; }
    var point = segment.mapToItem(root, 0, 0);
    var start = root.vertical ? point.y : point.x;
    // Stop the active-window line before the plate's rounded right corner.
    var rightInset = !root.vertical && segment === focus ? root.tokens.gap : 0;
    var endPoint = segment.mapToItem(root, Math.max(0, segment.width - rightInset), segment.height);
    var end = root.vertical ? endPoint.y : endPoint.x;
    var minimum = root.vertical ? viewport.y : viewport.x;
    var maximum = minimum + (root.vertical ? viewport.height : viewport.width);
    start = Math.max(start, minimum);
    end = Math.min(end, maximum);
    if (end <= start) { indicator.clear(); return; }
    indicator.retarget(start, end - start);
  }
  Components.HoverIndex {
    id: sharedIndex
    objectName: "sharedHoverIndex"
    anchors.fill: parent
    tokens: root.tokens
    vertical: root.vertical
    rightEdge: root.settings.value.position === "right"
    ink: root.hoveredSegment === battery && battery.warning ? root.tokens.alert
      : root.hoveredSegment === clock ? clock.accent
      : root.hoveredSegment === music ? music.ink
      : root.hoveredSegment === focus ? focus.ink
      : root.hoveredSegment === networkNode ? networkNode.ink
      : root.hoveredSegment === audio ? audio.ink
      : root.hoveredSegment === battery ? battery.ink
      : root.hoveredSegment === capture ? capture.ink
      : root.hoveredSegment === notifications ? notifications.ink
      : root.hoveredSegment === tray ? tray.ink : root.tokens.cyan
  }
  Components.HoverIndex {
    id: warningIndex
    objectName: "batteryWarningIndex"
    anchors.fill: parent
    tokens: root.tokens
    vertical: root.vertical
    rightEdge: root.settings.value.position === "right"
    ink: root.tokens.alert
    animate: false
  }
  function syncIndicators(): void {
    syncIndicator(sharedIndex, hoveredSegment);
    syncIndicator(warningIndex, battery.warning && hoveredSegment !== battery ? battery : null);
  }
  onHoveredSegmentChanged: syncIndicators()
  Connections { target: battery; function onWarningChanged(): void { root.syncIndicators(); } }
  // Mapping is refreshed during scroll, layout, scale and visibility changes,
  // without restarting a transition whose destination has not changed.
  Timer { interval: 16; running: root.hoveredSegment !== null || battery.warning; repeat: true; onTriggered: root.syncIndicators() }
}
