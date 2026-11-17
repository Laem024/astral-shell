pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Logic.js" as Logic
import "../common" as Common

Pane {
  id: root
  required property var service
  required property var tokens
  property string tab: "Local"
  property string searchText: ""
  property bool filtersOpen: false
  readonly property var tabs: ["Local", "Wallhaven", "Settings"]
  readonly property var tabLabels: ["Library", "Wallhaven", "Settings"]
  function setFilter(name, value) {
    service.searchFilters = Object.assign({}, service.searchFilters, {[name]: value});
  }
  function browseLatest() {
    search.text = "";
    service.searchFilters = ({});
    service.openWallhaven();
  }
  property string downloadTarget: "mode"
  property string draftLayout: "Mirror"
  property string targetMonitor: service.screens.length ? service.screens[0].name : ""
  property string downloadNotice: ""
  property var selected: null
  readonly property string activeTheme: service.collection === "light" ? "Light" : "Dark"
  readonly property string downloadCollection: downloadTarget === "shared" ? "shared" : service.collection
  onTargetMonitorChanged: service.invalidateDownloadTarget()
  onDownloadTargetChanged: service.invalidateDownloadTarget()
  onDraftLayoutChanged: service.invalidateDownloadTarget()
  readonly property var previewEntry: selected
  readonly property bool confirmationOpen: confirmation.opened
  function dismissConfirmation() { confirmation.close(); }
  readonly property bool remote: tab === "Wallhaven"
  readonly property var items: remote ? service.remoteEntries : Logic.collection(service.entries, service.collection, searchText)
  signal closeRequested()
  padding: 24
  font.family: tokens.font
  font.pixelSize: 13
  palette { window: tokens.surface; base: tokens.background; button: tokens.surface; text: tokens.text; buttonText: tokens.text; windowText: tokens.text; highlight: tokens.cyan; highlightedText: tokens.background; mid: tokens.border; placeholderText: tokens.muted }
  background: Rectangle { color: root.tokens.surface; radius: root.tokens.panelRadius; border.width: 1; border.color: root.tokens.border }
  focus: true
  Keys.onEscapePressed: closeRequested()
  function reset() {
    confirmation.close(); selected = null; grid.currentIndex = -1;
    search.text = tab === "Wallhaven" ? service.query : searchText;
    if (tab === "Wallhaven") browseLatest();
    search.forceActiveFocus();
  }
  function choose(index) {
    if (index < 0 || index >= items.length) return;
    downloadNotice = ""; draftLayout = service.state.layout; downloadTarget = "mode"; selected = items[index]; grid.currentIndex = index; confirmation.open();
  }
  onTabChanged: {
    service.invalidateDownloadTarget()
    confirmation.close(); selected = null; grid.currentIndex = -1;
    search.text = tab === "Wallhaven" ? service.query : searchText;
    if (tab === "Wallhaven") browseLatest();
  }
  onItemsChanged: {
    grid.currentIndex = -1;
    if (selected && !items.some(e => (e.path || e.id) === (selected.path || selected.id))) {
      confirmation.close(); selected = null;
    }
  }
  Connections {
    target: root.service
    function onDownloaded(source, path) {
      if (root.selected && root.selected.path === source) root.downloadNotice = "Saved to " + path;
    }
    function onApplied() { confirmation.close(); }
    function onScreensChanged() { if (!root.service.screens.some(s => s.name === root.targetMonitor)) root.targetMonitor = root.service.screens.length ? root.service.screens[0].name : ""; }
  }
  ColumnLayout {
    anchors.fill: parent; spacing: 16
    RowLayout {
      Layout.fillWidth: true
      spacing: 16
      ColumnLayout {
        Layout.fillWidth: true; Layout.minimumWidth: 0; spacing: 4
        Label { text: "ASTRAL · WALLPAPERS"; color: root.tokens.cyan; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.5 }
        Label { Layout.fillWidth: true; text: "Wallpapers"; font.pixelSize: 28; font.bold: true; elide: Text.ElideRight }
        Label { Layout.fillWidth: true; text: "Browse. Preview. Give your desktop a fresh look."; wrapMode: Text.Wrap; color: root.tokens.muted; font.pixelSize: 13 }
      }
      ToolButton {
        Layout.alignment: Qt.AlignTop
        implicitWidth: 36; implicitHeight: 36
        text: "✕"
        hoverEnabled: true
        Accessible.name: "Close wallpaper selector"
        onClicked: root.closeRequested()
        background: Rectangle {
          radius: height / 2
          color: parent.hovered ? Qt.alpha(root.tokens.text, 0.08) : "transparent"
          border.width: parent.activeFocus ? 2 : 1
          border.color: parent.activeFocus || parent.hovered ? root.tokens.text : root.tokens.border
        }
      }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 12
      WallpaperSegment {
        tokens: root.tokens
        options: root.tabLabels
        currentIndex: root.tabs.indexOf(root.tab)
        onActivated: index => root.tab = root.tabs[index]
        Accessible.name: "Wallpaper source"
      }
      Item { Layout.fillWidth: true }
    }
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
    RowLayout {
      visible: root.tab === "Local"; spacing: 8
      Label { text: "FOLDER"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; color: root.tokens.muted }
      TextField {
        implicitHeight: 38
        id: libraryFolder
        Layout.fillWidth: true
        text: root.service.state.folder
        selectByMouse: true
        font.family: root.tokens.mono; font.pixelSize: 12
        leftPadding: 14; rightPadding: 14
        color: root.tokens.text
        background: Rectangle { radius: 10; color: root.tokens.sunken; border.width: parent.activeFocus ? 2 : 1; border.color: parent.activeFocus ? root.tokens.cyan : root.tokens.border }
        Accessible.name: "Wallpaper folder"
        onAccepted: if (openFolder.enabled) openFolder.clicked()
      }
      WallpaperButton { tokens: root.tokens;
        id: openFolder
        text: "Open folder"
        enabled: libraryFolder.text.startsWith("/") && !root.service.transaction
        onClicked: {
          const path = libraryFolder.text.replace(/\/+$/, "") || "/";
          if (path === root.service.state.folder) root.service.refresh();
          else root.service.update("folder", path);
        }
      }
    }
    RowLayout {
      visible: root.tab !== "Settings"; spacing: 8
      TextField {
        implicitHeight: 38
        id: search
        Layout.fillWidth: true
        leftPadding: 14; rightPadding: 14
        color: root.tokens.text
        placeholderText: root.remote ? "Search landscapes, architecture, space… on Wallhaven" : "Filter images by name…"
        selectByMouse: true
        background: Rectangle { radius: 10; color: root.tokens.sunken; border.width: parent.activeFocus ? 2 : 1; border.color: parent.activeFocus ? root.tokens.cyan : root.tokens.border }
        onTextEdited: if (root.tab === "Local") root.searchText = text
        onAccepted: if (root.remote) root.service.search(text, 1); else { grid.forceActiveFocus(); root.choose(0); }
        Keys.onDownPressed: { grid.forceActiveFocus(); grid.currentIndex = root.items.length ? 0 : -1; }
      }
      WallpaperButton { tokens: root.tokens;
        text: root.remote ? "Search" : "Refresh"
        highlighted: root.remote
        enabled: !root.service.scanning && !root.service.remoteBusy
        onClicked: if (root.remote) root.service.search(search.text, 1); else root.service.refresh()
      }
    }
    RowLayout {
      visible: root.remote
      Layout.fillWidth: true
      spacing: 8
      WallpaperButton { tokens: root.tokens; text: root.filtersOpen ? "Hide filters" : "Search filters"; onClicked: root.filtersOpen = !root.filtersOpen }
      WallpaperButton { tokens: root.tokens; text: "Latest / Reset"; enabled: !root.service.remoteBusy; onClicked: root.browseLatest() }
      Label { Layout.fillWidth: true; text: root.service.keySaved ? "API key saved · authenticated searches" : "Public search · no API key"; color: root.tokens.muted; wrapMode: Text.Wrap; elide: Text.ElideRight; font.pixelSize: 11 }
    }
    ScrollView {
      visible: root.remote && root.filtersOpen
      Layout.fillWidth: true
      Layout.preferredHeight: 200
      clip: true
      contentWidth: availableWidth
      background: Rectangle { radius: root.tokens.cardRadius; color: root.tokens.raised; border.width: 1; border.color: root.tokens.border }
      Item {
        width: parent.width
        implicitHeight: filterGrid.implicitHeight + 24
        GridLayout {
          id: filterGrid
          x: 16; y: 12
          width: parent.width - 32
          columns: 2; columnSpacing: 16; rowSpacing: 10
          Label { text: "Categories"; color: root.tokens.muted }
          RowLayout {
            spacing: 12
            Repeater {
              model: ["General", "Anime", "People"]
              CheckBox {
                required property string modelData
                required property int index
                text: modelData
                checked: (root.service.searchFilters.categories || "111")[index] === "1"
                onToggled: {
                  const bits = (root.service.searchFilters.categories || "111").split("");
                  bits[index] = checked ? "1" : "0";
                  root.setFilter("categories", bits.join(""));
                }
              }
            }
          }
          Label { text: "Content"; color: root.tokens.muted }
          RowLayout {
            spacing: 12
            Repeater {
              model: ["SFW", "Sketchy", "NSFW"]
              CheckBox {
                required property string modelData
                required property int index
                text: modelData
                enabled: index !== 2 || root.service.keySaved
                checked: (root.service.searchFilters.purity || "100")[index] === "1"
                onToggled: {
                  const bits = (root.service.searchFilters.purity || "100").split("");
                  bits[index] = checked ? "1" : "0";
                  root.setFilter("purity", bits.join(""));
                }
              }
            }
          }
          Label { text: "Sort"; color: root.tokens.muted }
          WallpaperComboBox {
            tokens: root.tokens; Layout.fillWidth: true
            property var values: ["", "date_added", "relevance", "random", "views", "favorites", "toplist"]
            model: ["Automatic (latest for empty search)", "Date added", "Relevance", "Random", "Views", "Favorites", "Toplist"]
            currentIndex: Math.max(0, values.indexOf(root.service.searchFilters.sorting || ""))
            onActivated: root.setFilter("sorting", values[currentIndex])
          }
          Label { text: "Order"; color: root.tokens.muted }
          WallpaperComboBox {
            tokens: root.tokens; Layout.fillWidth: true; model: ["Descending", "Ascending"]
            currentIndex: root.service.searchFilters.order === "asc" ? 1 : 0
            onActivated: root.setFilter("order", currentIndex === 1 ? "asc" : "desc")
          }
          Label { text: "Toplist period"; color: root.tokens.muted }
          WallpaperComboBox {
            tokens: root.tokens; Layout.fillWidth: true; model: ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]
            enabled: root.service.searchFilters.sorting === "toplist"
            currentIndex: Math.max(0, model.indexOf(root.service.searchFilters.topRange || "1M"))
            onActivated: root.setFilter("topRange", currentText)
          }
          Label { text: "Minimum resolution"; color: root.tokens.muted }
          TextField {
            Layout.fillWidth: true; implicitHeight: 38; leftPadding: 14; rightPadding: 14
            color: root.tokens.text; font.family: root.tokens.mono; font.pixelSize: 12
            placeholderText: "1920x1080"; text: root.service.searchFilters.atleast || ""
            background: Rectangle { radius: 10; color: root.tokens.sunken; border.width: parent.activeFocus ? 2 : 1; border.color: parent.activeFocus ? root.tokens.cyan : root.tokens.border }
            onTextEdited: { root.setFilter("atleast", text.trim()); root.setFilter("resolutions", ""); }
          }
          Label { text: "Exact resolution"; color: root.tokens.muted }
          TextField {
            Layout.fillWidth: true; implicitHeight: 38; leftPadding: 14; rightPadding: 14
            color: root.tokens.text; font.family: root.tokens.mono; font.pixelSize: 12
            placeholderText: "2560x1440"; text: root.service.searchFilters.resolutions || ""
            background: Rectangle { radius: 10; color: root.tokens.sunken; border.width: parent.activeFocus ? 2 : 1; border.color: parent.activeFocus ? root.tokens.cyan : root.tokens.border }
            onTextEdited: { root.setFilter("resolutions", text.trim()); root.setFilter("atleast", ""); }
          }
          Label { text: "Aspect ratio"; color: root.tokens.muted }
          WallpaperComboBox {
            tokens: root.tokens; Layout.fillWidth: true
            property var values: ["", "landscape", "portrait", "16x9", "16x10", "21x9", "32x9", "48x9", "9x16", "10x16", "9x18", "1x1", "3x2", "4x3", "5x4"]
            model: ["Any", "Landscape", "Portrait", "16x9", "16x10", "21x9", "32x9", "48x9", "9x16", "10x16", "9x18", "1x1", "3x2", "4x3", "5x4"]
            currentIndex: Math.max(0, values.indexOf(root.service.searchFilters.ratios || ""))
            onActivated: root.setFilter("ratios", values[currentIndex])
          }
          Label { text: "Color (hex)"; color: root.tokens.muted }
          WallpaperComboBox {
            tokens: root.tokens; Layout.fillWidth: true
            property var values: ["", "660000", "990000", "cc0000", "cc3333", "ea4c88", "993399", "663399", "333399", "0066cc", "0099cc", "66cccc", "77cc33", "669900", "336600", "666600", "999900", "cccc33", "ffff00", "ffcc33", "ff9900", "ff6600", "cc6633", "996633", "663300", "000000", "999999", "cccccc", "ffffff", "424153"]
            model: ["Any"].concat(values.slice(1))
            currentIndex: Math.max(0, values.indexOf(root.service.searchFilters.colors || ""))
            onActivated: root.setFilter("colors", values[currentIndex])
          }
          Label { Layout.columnSpan: 2; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12; text: "Apply filters with Search. Query syntax: +tag -tag, @username, id:123, type:png, like:ID."; color: root.tokens.muted }
        }
      }
    }
    Label {
      Layout.fillWidth: true; wrapMode: Text.Wrap
      visible: text.length > 0
      color: root.service.error ? root.tokens.alert : root.tokens.gold
      text: root.service.error || root.service.warning
      font.pixelSize: 12
    }
    Label {
      Layout.fillWidth: true; wrapMode: Text.Wrap
      visible: text.length > 0 && !root.service.error
      text: root.service.notice; color: root.tokens.cyan
      font.pixelSize: 12
    }
    RowLayout {
      visible: root.tab !== "Settings"
      Layout.fillWidth: true; Layout.fillHeight: true; spacing: 16
      ColumnLayout {
        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label { text: root.remote ? "DISCOVER" : "YOUR LIBRARY · " + root.activeTheme.toUpperCase(); font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; color: root.tokens.muted }
          Item { Layout.fillWidth: true }
          BusyIndicator { implicitWidth: 20; implicitHeight: 20; running: root.service.scanning || root.service.remoteBusy; visible: running }
          Label { text: root.items.length + " wallpapers"; color: root.tokens.muted; font.family: root.tokens.mono; font.pixelSize: 11 }
        }
        Rectangle {
          Layout.fillWidth: true; Layout.fillHeight: true
          radius: root.tokens.cardRadius
          color: root.tokens.sunken
          border.width: 1; border.color: root.tokens.border
          clip: true
          GridView {
            id: grid
            objectName: "wallpaperGrid"
            anchors.fill: parent; anchors.margins: 8; clip: true
            model: root.items
            currentIndex: -1
            cellWidth: width / Math.max(1, Math.floor(width / 216))
            cellHeight: cellWidth * 0.62 + 46
            cacheBuffer: cellHeight
            keyNavigationEnabled: true
            activeFocusOnTab: true
            Keys.onReturnPressed: root.choose(currentIndex)
            delegate: Item {
              id: tile
              required property var modelData
              required property int index
              readonly property bool chosen: !!root.selected && root.selected.path === modelData.path
              readonly property bool applied: !root.remote && Object.values(root.service.activePaths).includes(modelData.path)
              width: grid.cellWidth; height: grid.cellHeight
              Rectangle {
                id: card
                anchors.fill: parent; anchors.margins: 6
                color: tile.chosen ? Qt.alpha(root.tokens.cyan, 0.12) : hover.hovered ? Qt.alpha(root.tokens.text, 0.05) : root.tokens.raised
                radius: root.tokens.cardRadius
                border.width: tile.chosen || grid.currentIndex === tile.index ? 2 : 1
                border.color: tile.chosen ? root.tokens.cyan
                  : hover.hovered ? Qt.alpha(root.tokens.cyan, 0.5) : root.tokens.border
                Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
                Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
                Rectangle {
                  id: thumbFrame
                  anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                  height: Math.max(1, parent.height - 46)
                  radius: root.tokens.rowRadius
                  color: root.tokens.sunken
                  clip: true
                  Common.RoundedClip {
                    anchors.fill: parent
                    radius: thumbFrame.radius
                    Loader {
                      id: thumbnailLoader
                      readonly property var image: item
                      anchors.fill: parent
                      sourceComponent: root.remote ? remoteThumb : localThumb
                      Component {
                        id: localThumb
                        Thumbnail { service: root.service; path: tile.modelData.path; sourceSize.width: 480 }
                      }
                      Component {
                        id: remoteThumb
                        Image {
                          source: tile.modelData.thumbs.large || tile.modelData.thumbs.small || ""
                          asynchronous: true; fillMode: Image.PreserveAspectCrop
                          sourceSize.width: 480
                        }
                      }
                    }
                  }
                  Label {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    horizontalAlignment: Text.AlignHCenter
                    visible: !thumbnailLoader.image || thumbnailLoader.image.status !== Image.Ready
                    text: thumbnailLoader.image && (thumbnailLoader.image.status === Image.Error || thumbnailLoader.image.failed) ? "Preview unavailable" : "Loading image…"
                    color: root.tokens.muted; font.pixelSize: 11
                  }
                  Rectangle {
                    anchors { left: parent.left; top: parent.top; margins: 8 }
                    visible: !root.remote
                    width: badge.implicitWidth + 16; height: 22; radius: 11
                    color: Qt.alpha(root.tokens.background, 0.92)
                    border.width: 1
                    border.color: tile.applied ? Qt.alpha(root.tokens.cyan, 0.6) : root.tokens.border
                    Label { id: badge; anchors.centerIn: parent; text: tile.applied ? "IN USE" : (tile.modelData.theme === "light" ? "LIGHT" : tile.modelData.theme === "dark" ? "DARK" : "SHARED"); font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8; color: tile.applied ? root.tokens.cyan : root.tokens.text }
                  }
                }
                Label {
                  anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 12; bottomMargin: 10 }
                  text: root.remote ? tile.modelData.resolution + " · " + tile.modelData.id : tile.modelData.name
                  font.family: root.remote ? root.tokens.mono : root.tokens.font
                  font.pixelSize: 11
                  elide: Text.ElideMiddle
                }
                HoverHandler { id: hover }
                MouseArea {
                  objectName: "wallpaperTile_" + tile.index
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { grid.forceActiveFocus(); root.choose(tile.index); }
                  Accessible.role: Accessible.Button
                  Accessible.name: root.remote ? "Wallpaper " + tile.modelData.id : tile.modelData.name
                  Accessible.onPressAction: root.choose(tile.index)
                }
              }
            }
            ScrollBar.vertical: ScrollBar {}
          }
          Column {
            anchors.centerIn: parent
            width: parent.width - 48; spacing: 10
            visible: !grid.count
            Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: root.service.scanning || root.service.remoteBusy ? "Searching images…" : root.remote ? "Your next wallpaper starts here" : "No images in this view"; font.pixelSize: 18; font.bold: true; wrapMode: Text.Wrap }
            Label {
              width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: root.tokens.muted; font.pixelSize: 13
              text: root.remote ? "No results. Adjust the filters or try another search." : "Open a folder with images or clear the filter. This view shows the active mode and shared wallpapers."
            }
          }
        }
        RowLayout {
          visible: root.remote
          Layout.fillWidth: true
          spacing: 8
          WallpaperButton { tokens: root.tokens; text: "← Previous"; enabled: !root.service.remoteBusy && root.service.page > 1; onClicked: root.service.search(root.service.query, root.service.page - 1, root.service.appliedSearchFilters) }
          Item { Layout.fillWidth: true }
          Label { text: root.service.page + " / " + root.service.lastPage; color: root.tokens.muted; font.family: root.tokens.mono; font.pixelSize: 12 }
          Item { Layout.fillWidth: true }
          WallpaperButton { tokens: root.tokens; text: "Next →"; enabled: !root.service.remoteBusy && root.service.page < root.service.lastPage; onClicked: root.service.search(root.service.query, root.service.page + 1, root.service.appliedSearchFilters) }
        }
      }
    }
    ScrollView {
      visible: root.tab === "Settings"
      Layout.fillWidth: true; Layout.fillHeight: true
      contentWidth: availableWidth
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      ColumnLayout {
        width: parent.width; spacing: 16
        ColumnLayout {
          Layout.fillWidth: true; spacing: 4
          Label { text: "Preferences"; font.pixelSize: 28; font.bold: true }
          Label { text: "Tune your library, appearance and automatic rotation."; Layout.fillWidth: true; wrapMode: Text.Wrap; color: root.tokens.muted; font.pixelSize: 13 }
        }
        WallpaperSection {
          tokens: root.tokens
          title: "Library"
          description: "Images directly under light/ and dark/ belong to that theme. Everything else is shared, and files are never moved."
          ColumnLayout {
            Layout.fillWidth: true; spacing: 8
            Label { text: "Wallpaper folder"; font.bold: true; font.pixelSize: 14 }
            RowLayout {
              Layout.fillWidth: true
              spacing: 8
              TextField {
                id: folder; implicitHeight: 38; Layout.fillWidth: true; text: root.service.state.folder
                placeholderText: "/absolute/path/to/wallpapers"; selectByMouse: true; Accessible.name: "Wallpaper folder"
                color: root.tokens.text; font.family: root.tokens.mono; font.pixelSize: 12; leftPadding: 14; rightPadding: 14
                background: Rectangle { radius: 10; color: root.tokens.sunken; border.width: parent.activeFocus ? 2 : 1; border.color: parent.activeFocus ? root.tokens.cyan : root.tokens.border }
              }
              WallpaperButton { tokens: root.tokens; text: "Save folder"; enabled: folder.text.startsWith("/"); onClicked: root.service.update("folder", folder.text.replace(/\/+$/, "") || "/") }
            }
          }
        }
        WallpaperSection {
          tokens: root.tokens
          title: "Appearance"
          description: "The theme also selects the matching wallpaper collection. The layout applies to every screen."
          ColumnLayout {
            Layout.fillWidth: true; spacing: 12
            RowLayout {
              Layout.fillWidth: true
              Label { text: "Theme"; font.bold: true; font.pixelSize: 14; Layout.fillWidth: true }
              WallpaperSegment {
                tokens: root.tokens; options: ["Light", "Dark"]
                currentIndex: root.service.collection === "light" ? 0 : 1
                onActivated: index => root.service.setTheme(index === 0 ? "Light" : "Dark")
              }
            }
            RowLayout {
              Layout.fillWidth: true
              Label { text: "Layout"; font.bold: true; font.pixelSize: 14; Layout.fillWidth: true }
              WallpaperComboBox {
                tokens: root.tokens; model: ["Mirror", "Span", "Per monitor"]
                currentIndex: ["Mirror", "Span", "Per monitor"].indexOf(root.service.state.layout)
                onActivated: root.service.update("layout", ["Mirror", "Span", "Per monitor"][currentIndex])
                Accessible.name: "Screen layout"
              }
            }
            RowLayout {
              Layout.fillWidth: true
              spacing: 8
              Label { text: "Transition"; font.bold: true; font.pixelSize: 14; Layout.fillWidth: true }
              SpinBox { from: 0; to: 5000; stepSize: 100; editable: true; value: root.service.state.fade; onValueModified: root.service.update("fade", value); Accessible.name: "Transition duration in milliseconds" }
              Label { text: "ms"; color: root.tokens.muted; font.pixelSize: 12 }
            }
            Label { text: "Set the transition to 0 to switch instantly."; Layout.fillWidth: true; wrapMode: Text.Wrap; color: root.tokens.muted; font.pixelSize: 11 }
          }
        }
        WallpaperSection {
          tokens: root.tokens
          title: "Rotation"
          description: "Refresh the active collection on a timer. The countdown pauses while the session is locked."
          ColumnLayout {
            Layout.fillWidth: true; spacing: 14
            RowLayout {
              Layout.fillWidth: true; spacing: 16
              ColumnLayout {
                Layout.fillWidth: true; spacing: 2
                Label { text: "Automatic rotation"; font.bold: true; font.pixelSize: 15 }
                Label {
                  Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 12
                  color: root.service.state.rotation ? root.tokens.cyan : root.tokens.muted
                  text: root.service.state.rotation
                    ? "Every " + root.service.state.minutes + (root.service.state.minutes === 1 ? " minute · " : " minutes · ") + (root.service.state.random ? "Random order" : "Sequential order")
                    : "Off · your current wallpaper stays in place"
                }
              }
              WallpaperSwitch {
                tokens: root.tokens
                checked: root.service.state.rotation
                onToggled: root.service.update("rotation", checked)
                Accessible.name: "Automatic rotation"
              }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
            ColumnLayout {
              Layout.fillWidth: true; spacing: 12
              enabled: root.service.state.rotation
              opacity: enabled ? 1 : 0.45
              RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Label { text: "Interval"; font.pixelSize: 14; Layout.fillWidth: true }
                SpinBox { from: 1; to: 10080; editable: true; value: root.service.state.minutes; onValueModified: root.service.update("minutes", value); Accessible.name: "Rotation interval in minutes" }
                Label { text: "minutes"; color: root.tokens.muted; font.pixelSize: 12 }
              }
              RowLayout {
                Layout.fillWidth: true
                Label { text: "Order"; font.pixelSize: 14; Layout.fillWidth: true }
                WallpaperSegment {
                  tokens: root.tokens; options: ["Random", "Sequential"]
                  currentIndex: root.service.state.random ? 0 : 1
                  onActivated: index => root.service.update("random", index === 0)
                }
              }
            }
          }
        }
        WallpaperSection {
          tokens: root.tokens
          title: "Wallhaven"
          description: "Optional private API key for authenticated searches. It is stored outside the repository and never passed as a command argument."
          ColumnLayout {
            Layout.fillWidth: true; spacing: 10
            Label { text: root.service.keySaved ? "A private key is saved." : "No key saved. You can search for public-safe images."; color: root.service.keySaved ? root.tokens.cyan : root.tokens.muted; Layout.fillWidth: true; wrapMode: Text.Wrap; font.pixelSize: 13 }
            RowLayout {
              Layout.fillWidth: true
              spacing: 8
              TextField {
                id: apiKey; implicitHeight: 38; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "API key"; selectByMouse: true; Accessible.name: "Wallhaven API key"
                color: root.tokens.text; leftPadding: 14; rightPadding: 14
                background: Rectangle { radius: 10; color: root.tokens.sunken; border.width: parent.activeFocus ? 2 : 1; border.color: parent.activeFocus ? root.tokens.cyan : root.tokens.border }
              }
              WallpaperButton { tokens: root.tokens; text: "Save key"; enabled: !root.service.keyBusy && apiKey.text.length > 0; onClicked: { root.service.setKey(apiKey.text); apiKey.clear(); } }
              WallpaperButton { tokens: root.tokens; text: "Remove key"; enabled: !root.service.keyBusy && root.service.keySaved; onClicked: { root.service.setKey(""); apiKey.clear(); } }
            }
          }
        }
        Label { text: "PNG, JPEG, WebP, BMP, animated GIF, and silent MP4, WebM, or MKV video. Video support depends on installed codecs. Span synchronizes playback periodically."; Layout.fillWidth: true; wrapMode: Text.Wrap; color: root.tokens.muted; font.pixelSize: 11; Layout.topMargin: 2 }
      }
    }
  }
  Item {
    id: confirmation
    objectName: "wallpaperConfirmation"
    anchors.fill: parent
    z: 100
    property bool opened: false
    visible: opened
    function open() { opened = true; forceActiveFocus(); }
    function close() {
      if (!opened) return;
      opened = false;
      grid.forceActiveFocus();
    }
    Keys.onEscapePressed: event => { close(); event.accepted = true; }
    Rectangle { anchors.fill: parent; color: Qt.alpha(root.tokens.background, 0.72) }
    MouseArea { anchors.fill: parent; onClicked: confirmation.close() }
    Pane {
      objectName: "wallpaperPreviewDialog"
      anchors.centerIn: parent
      width: Math.max(1, Math.min(680, parent.width - 32))
      height: Math.max(1, Math.min(740, parent.height - 32))
      padding: parent.height < 500 ? 16 : 24
      clip: true
      font: root.font
      palette: root.palette
      background: Rectangle {
        color: root.tokens.surface; radius: root.tokens.panelRadius; border.width: 1; border.color: root.tokens.border
        MouseArea { anchors.fill: parent }
      }
      contentItem: ColumnLayout {
        spacing: 14
        ScrollView {
          id: previewScroll
          objectName: "wallpaperPreviewScroll"
          clip: true
          // Keep the action row in the popup's viewport when the display is
          // short or the interface scale is large. The preview details scroll.
          Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 0
          contentWidth: availableWidth
          ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
          ColumnLayout {
            width: previewScroll.availableWidth; spacing: 12
            Label { text: "SELECTED WALLPAPER"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.4; color: root.tokens.cyan }
            Rectangle {
              Layout.fillWidth: true; Layout.preferredHeight: Math.max(120, Math.min(300, root.height * 0.36))
              color: root.tokens.sunken; radius: root.tokens.cardRadius; clip: true
              border.width: 1; border.color: root.tokens.border
              Common.RoundedClip {
                anchors.fill: parent
                radius: root.tokens.cardRadius
                Loader {
                  id: previewLoader
                  readonly property var media: item
                  objectName: "wallpaperPreview"
                  anchors.fill: parent
                  active: confirmation.visible && !!root.previewEntry && root.tab !== "Settings"
                  sourceComponent: root.remote ? remotePreview : localPreview
                  Component {
                    id: remotePreview
                    Image {
                      source: root.previewEntry ? root.previewEntry.thumbs.large || root.previewEntry.thumbs.small || "" : ""
                      asynchronous: true; fillMode: Image.PreserveAspectFit
                    }
                  }
                  Component {
                    id: localPreview
                    WallpaperMedia {
                      path: root.previewEntry ? root.previewEntry.path : ""
                      paused: root.service.blocked
                      fit: true
                      property string previewError: ""
                      onPathChanged: previewError = ""
                      onFailed: detail => previewError = detail
                    }
                  }
                }
              }
              Label {
                anchors.centerIn: parent; width: parent.width - 32; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                visible: !root.previewEntry || (previewLoader.media && (root.remote ? previewLoader.media.status !== Image.Ready : !previewLoader.media.primed))
                text: !root.previewEntry ? "Select an image" : previewLoader.media && (root.remote ? previewLoader.media.status === Image.Error : previewLoader.media.previewError) ? "Could not load the preview" : "Loading preview…"
                color: root.tokens.muted; font.pixelSize: 13
              }
            }
            Label { Layout.fillWidth: true; maximumLineCount: 2; elide: Text.ElideMiddle; wrapMode: Text.Wrap; text: root.previewEntry ? root.previewEntry.name || ("Wallhaven · " + root.previewEntry.id) : "Find your wallpaper"; font.pixelSize: 18; font.bold: true }
            Label {
              Layout.fillWidth: true; maximumLineCount: 2; elide: Text.ElideMiddle; wrapMode: Text.Wrap; color: root.tokens.muted; font.pixelSize: 11
              font.family: root.tokens.mono
              text: root.previewEntry ? root.remote ? root.previewEntry.resolution : root.previewEntry.relative || root.previewEntry.path : "Click a card to choose your wallpaper."
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
            Label { text: "APPLY ON"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; color: root.tokens.muted }
            WallpaperComboBox { tokens: root.tokens; enabled: !root.service.remoteBusy && !root.service.transaction; implicitHeight: 38; Layout.fillWidth: true; model: ["Mirror", "Span", "Per monitor"]; currentIndex: ["Mirror", "Span", "Per monitor"].indexOf(root.draftLayout); onActivated: root.draftLayout = ["Mirror", "Span", "Per monitor"][currentIndex]; Accessible.name: "Screen layout" }
            WallpaperComboBox { tokens: root.tokens;
              enabled: !root.service.remoteBusy && !root.service.transaction
              implicitHeight: 38
              Layout.fillWidth: true
              visible: root.draftLayout === "Per monitor"
              model: root.service.screens.map(s => s.name)
              currentIndex: Math.max(0, model.indexOf(root.targetMonitor))
              onActivated: root.targetMonitor = currentText
              Accessible.name: "Target monitor"
            }
            Label { visible: root.draftLayout !== "Per monitor"; text: "All screens"; color: root.tokens.muted; font.pixelSize: 12 }
            Label { visible: root.remote; text: "DOWNLOAD TO"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.2; color: root.tokens.muted }
            WallpaperComboBox {
              tokens: root.tokens; Layout.fillWidth: true
              visible: root.remote
              objectName: "wallpaperDownloadTarget"
              enabled: !root.service.remoteBusy && !root.service.transaction
              implicitHeight: 38
              model: ["Current mode (" + root.activeTheme + ")", "Shared (both modes)"]
              currentIndex: root.downloadTarget === "shared" ? 1 : 0
              onActivated: root.downloadTarget = currentIndex === 0 ? "mode" : "shared"
              Accessible.name: "Download destination"
            }
            Label {
              Layout.fillWidth: true; visible: !root.remote; wrapMode: Text.Wrap; color: root.tokens.muted; font.pixelSize: 12
              text: "Applies to the active collection (" + root.activeTheme + ")."
            }
            Label {
              Layout.fillWidth: true; elide: Text.ElideMiddle; font.pixelSize: 12; color: root.tokens.muted
              text: root.selected ? "Selection: " + (root.selected.name || root.selected.id) : "No wallpaper selected"
            }
            Label {
              Layout.fillWidth: true; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideMiddle
              visible: root.remote && root.downloadNotice.length > 0 && !root.service.error
              text: root.downloadNotice; color: root.tokens.cyan; font.pixelSize: 12
            }
          }
        }
        Label {
          Layout.fillWidth: true; wrapMode: Text.Wrap; visible: text.length > 0
          text: root.service.error || root.service.notice
          color: root.service.error ? root.tokens.alert : root.tokens.cyan
          font.pixelSize: 12
        }
        Flow {
          objectName: "wallpaperActions"
          Layout.fillWidth: true; Layout.minimumHeight: 38; spacing: 8
          WallpaperButton {
            tokens: root.tokens; text: "Back"; onClicked: confirmation.close()
          }
          WallpaperButton {
            tokens: root.tokens; objectName: "wallpaperDownload"
            visible: root.remote; text: "Download"
            enabled: !!root.selected && !root.service.remoteBusy && !root.service.scanning && !root.service.transaction && !root.service.blocked
            onClicked: root.service.download(root.selected, root.downloadCollection, root.targetMonitor, "download", root.service.collection, root.draftLayout)
          }
          WallpaperButton {
            tokens: root.tokens; objectName: "wallpaperApply"
            text: root.service.transaction ? "Preparing…" : root.service.remoteBusy ? "Downloading…" : "Apply now"
            highlighted: true
            enabled: !!root.selected && !root.service.transaction && !root.service.remoteBusy && !root.service.scanning && !root.service.blocked
            onClicked: if (root.remote) root.service.download(root.selected, root.downloadCollection, root.targetMonitor, "manual", root.service.collection, root.draftLayout); else root.service.apply(root.selected.path, root.targetMonitor, root.draftLayout)
          }
        }
      }
    }
  }
}
