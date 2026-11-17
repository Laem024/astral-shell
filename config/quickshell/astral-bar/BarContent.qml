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
      + (child.Layout.minimumWidth > 0 ? child.Layout.minimumWidth
        : child.Layout.fillWidth ? 0 : child.implicitWidth)
      + child.Layout.leftMargin + child.Layout.rightMargin, 0)
      + Math.max(0, children.length - 1) * group.columnSpacing;
  }
  function labeledEndMinimum() {
    const dockCount = ["tray", "capture", "network", "audio", "battery", "notifications"].filter(key => shown[key]).length;
    const dockWidth = dockCount ? 16 + Number(!!shown.tray) * 36 + Number(!!shown.capture) * 40 + Number(!!shown.network) * 36
      + Number(!!shown.audio) * 70 + Number(!!shown.battery) * 70
      + Number(!!shown.notifications) * 58 + Math.max(0, dockCount - 1) * 2 : 0;
    const groupCount = Number(!!shown.music) + Number(dockCount > 0)
      + Number(!!shown.music && !!shown.tray);
    return dockWidth + Number(!!shown.music) * 148
      + Number(!!shown.music && !!shown.tray) * 10
      + Math.max(0, groupCount - 1) * tokens.gap;
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
      id: startPlate
      objectName: "startPlate"
      x: root.vertical ? (viewport.width - root.verticalPlateWidth) / 2 : startGroup.x * composition.scale
      y: root.vertical ? startGroup.y * composition.scale : (composition.height - height) / 2
      scale: composition.scale
      transformOrigin: Item.TopLeft
      width: root.vertical ? root.verticalPlateWidth / composition.scale : startGroup.width
      height: root.vertical ? startGroup.height : Math.max(0, Math.min(composition.height - 4, Math.max(startGroup.height, endGroup.height) + 6))
      visible: (root.shown.logo || root.shown.clock || (root.shown.window && (root.vertical || !root.compact)))
      radius: 18; color: root.tokens.sunken; border.color: root.tokens.border
    }
    Rectangle {
      id: endPlate
      objectName: "endPlate"
      x: root.vertical ? (viewport.width - root.verticalPlateWidth) / 2 : endGroup.x * composition.scale
      y: root.vertical ? endGroup.y * composition.scale : (composition.height - height) / 2
      scale: composition.scale
      transformOrigin: Item.TopLeft
      width: root.vertical ? root.verticalPlateWidth / composition.scale : endGroup.width
      height: root.vertical ? endGroup.height : Math.max(0, Math.min(composition.height - 4, Math.max(startGroup.height, endGroup.height) + 6))
      visible: true
      radius: 18; color: root.tokens.sunken; border.color: root.tokens.border
    }
    GridLayout {
      id: composition
      objectName: "composition"
      readonly property real sideMinimum: Math.max(root.minimumGroupWidth(startGroup), root.minimumGroupWidth(endGroup))
      readonly property real sideExtent: Math.max(sideMinimum, (width - (root.shown.workspaces ? centerWorkspaces.implicitWidth + 2 * columnSpacing : columnSpacing)) / 2)
      readonly property int visibleGroups: Number(startGroup.visible) + Number(root.shown.workspaces) + Number(endGroup.visible)
      readonly property real minimumVerticalHeight: (startGroup.visible ? startGroup.implicitHeight : 0)
        + (endGroup.visible ? endGroup.implicitHeight : 0)
        + (root.shown.workspaces ? workspaceContainer.implicitHeight : 0)
        + Math.max(0, visibleGroups - 1) * rowSpacing
      scale: root.vertical ? Math.min(1, viewport.height / Math.max(1, minimumVerticalHeight)) : 1
      transformOrigin: Item.TopLeft
      width: viewport.contentWidth / scale
      height: viewport.contentHeight / scale
      columns: root.vertical ? 1 : 3
      columnSpacing: !root.vertical && root.minimal ? root.tokens.unit : root.tokens.section
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
          Layout.alignment: Qt.AlignCenter
          tokens: root.tokens
          logoGlyph: root.settings.value.logo.glyph
          logoImage: root.settings.value.logo.image
        }
        Rectangle {
          objectName: "logoClockDivider"
          visible: clock.visible
          Layout.topMargin: root.vertical && !logo.visible ? 12 : 0
          implicitWidth: root.vertical ? 20 : 1
          implicitHeight: root.vertical ? 1 : 20
          Layout.alignment: Qt.AlignCenter
          color: root.tokens.border
        }
        Modules.ClockModule {
          id: clock
          Layout.bottomMargin: root.vertical && !focus.visible ? 12 : 0
          Layout.maximumWidth: implicitWidth
          visible: root.shown.clock
          Layout.alignment: Qt.AlignCenter
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
          Layout.fillHeight: false
          Layout.rightMargin: root.vertical ? 0 : root.tokens.gap
          visible: root.shown.window && (root.vertical || !root.compact)
          Layout.alignment: Qt.AlignCenter
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
        Layout.alignment: root.vertical ? Qt.AlignHCenter | Qt.AlignBottom : Qt.AlignVCenter
        columns: root.vertical ? 1 : 9
        columnSpacing: root.minimal ? root.tokens.unit / 2 : root.tokens.gap
        rowSpacing: root.vertical ? 6 : root.tokens.gap
        Item { visible: !root.vertical; Layout.fillWidth: true }
        Modules.MusicModule {
          id: music
          Layout.fillWidth: !root.vertical && !root.compact
          Layout.minimumWidth: root.vertical ? 48 : 148
          Layout.preferredWidth: root.vertical || root.compact ? music.implicitWidth
            : Math.max(340, Math.min(420, root.width * 0.2))
          Layout.maximumWidth: root.vertical || root.compact ? music.implicitWidth : 420
          Layout.topMargin: root.vertical ? 12 : 0
          Layout.bottomMargin: 0
          visible: root.shown.music
          Layout.alignment: Qt.AlignCenter
          tokens: root.tokens
          onActivated: root.navigate("Media", music)
          vertical: root.vertical
          compact: root.compact || (!root.vertical && width < 220)
        }
        Components.Constellation {
          objectName: "musicTrayDivider"
          visible: root.shown.music && root.shown.tray
          Layout.alignment: Qt.AlignCenter
          tokens: root.tokens
          vertical: root.vertical
        }
        Item {
          id: statusDock
          objectName: "statusDock"
          visible: root.shown.tray || root.shown.capture || root.shown.network || root.shown.audio || root.shown.battery || root.shown.notifications
          implicitWidth: statusLayout.implicitWidth + (root.vertical ? 8 : 16)
          implicitHeight: statusLayout.implicitHeight + 8
          Layout.alignment: Qt.AlignCenter
          Layout.topMargin: root.vertical && !root.shown.music ? 8 : 0
          Layout.bottomMargin: root.vertical ? 8 : 0
          GridLayout {
            id: statusLayout
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: root.vertical ? 0 : -4
            columns: root.vertical ? 1 : 6
            columnSpacing: 2
            rowSpacing: 4
            Modules.TrayModule {
              id: tray
              compact: !root.vertical && root.minimal
              Layout.topMargin: 0
              Layout.bottomMargin: 0
              visible: root.shown.tray
              Layout.alignment: Qt.AlignCenter
              tokens: root.tokens
              panel: root
              navigation: root.navigation
              nativeWindow: root.nativeWindow
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
              Layout.topMargin: 0
              Layout.bottomMargin: 0
              onClicked: {
                if (recording) Data.CaptureData.stop();
                else root.navigate("Display", capture);
              }
            }
            Modules.NetworkModule {
              id: networkNode
              Layout.topMargin: 0
              Layout.bottomMargin: 0
              visible: root.shown.network
              Layout.alignment: Qt.AlignCenter
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
              Layout.alignment: Qt.AlignCenter
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
              Layout.alignment: Qt.AlignCenter
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
              Layout.bottomMargin: 0
              visible: root.shown.notifications
              Layout.alignment: Qt.AlignCenter
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
}
