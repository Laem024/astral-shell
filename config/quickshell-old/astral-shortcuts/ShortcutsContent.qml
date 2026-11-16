pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Logic.js" as Logic
import "data" as Data

FocusScope {
  id: root
  required property var tokens
  property bool active: false
  property int categoryIndex: 0
  property string query: ""
  property var modifiers: []
  focus: root.active

  readonly property var shortcuts: Data.ShortcutsData
  readonly property bool compact: width < 900 || height < 590
  readonly property bool narrow: width < 780
  readonly property bool filtering: root.query.trim() !== "" || root.modifiers.length > 0
  readonly property int cardGap: root.compact ? 10 : 14
  readonly property int entryColumns: (root.compact || root.narrow) ? 1 : 2

  readonly property var rail: Logic.railFor(root.shortcuts.categories, root.shortcuts.total)
  readonly property string selected: root.rail.length > 0
    ? root.rail[Logic.clampIndex(root.categoryIndex, root.rail.length)].name : "All"
  readonly property var filtered: Logic.filterCategories(root.shortcuts.categories, root.query, root.modifiers)
  readonly property var display: root.selected === "All"
    ? root.filtered
    : root.filtered.filter(category => category.name === root.selected)
  readonly property var masonry: Logic.splitColumns(root.display)
  readonly property int visibleTotal: Logic.countEntries(root.filtered)
  readonly property int displayTotal: Logic.countEntries(root.display)
  readonly property bool single: root.selected !== "All" || root.filtering
  readonly property bool listMode: root.single || root.narrow || root.display.length < 2
  // Flat rows remain available to checks and other consumers; the card view
  // groups the same entries visually.
  readonly property var rows: Logic.rowsFor(root.display, root.selected)

  readonly property string subtitle: {
    if (root.shortcuts.error !== "") return root.shortcuts.error;
    if (root.shortcuts.loading) {
      return root.shortcuts.categories.length === 0
        ? "Reading active bindings from Hyprland…"
        : "Refreshing active bindings…";
    }
    if (root.shortcuts.total === 0) return "No active bindings found.";
    if (root.filtering) {
      if (root.selected !== "All") {
        return root.displayTotal + (root.displayTotal === 1 ? " match" : " matches")
          + " in " + root.selected + " · " + root.visibleTotal + " overall";
      }
      return root.visibleTotal + (root.visibleTotal === 1 ? " match" : " matches")
        + " of " + root.shortcuts.total + " active bindings";
    }
    return root.shortcuts.total
      + (root.shortcuts.total === 1 ? " active binding" : " active bindings")
      + " · " + root.shortcuts.categories.length
      + (root.shortcuts.categories.length === 1 ? " category" : " categories");
  }
  readonly property color subtitleColor: root.shortcuts.error !== ""
    ? root.tokens.alert : root.shortcuts.loading ? root.tokens.gold : root.tokens.muted
  readonly property string syncLabel: root.shortcuts.error !== "" ? "OFFLINE"
    : root.shortcuts.loading ? "SYNCING" : "LIVE"
  readonly property color syncColor: root.shortcuts.error !== "" ? root.tokens.alert
    : root.shortcuts.loading ? root.tokens.gold : root.tokens.cyan
  readonly property bool emptyView: !root.shortcuts.loading && root.shortcuts.error === ""
    && root.shortcuts.categories.length > 0 && root.displayTotal === 0

  signal closeRequested()

  function reset(): void {
    root.categoryIndex = 0;
    root.query = "";
    root.modifiers = [];
    root.scrollTop();
    if (root.active) Qt.callLater(() => { if (root.active) root.forceActiveFocus(); });
  }
  function select(index: int): void {
    if (root.rail.length === 0) return;
    root.categoryIndex = (index + root.rail.length) % root.rail.length;
    root.scrollTop();
  }
  function scroll(delta: real): void {
    if (!flick) return;
    const maximum = Math.max(0, flick.contentHeight - flick.height);
    flick.contentY = Math.max(0, Math.min(maximum, flick.contentY + delta));
  }
  function scrollTop(): void {
    if (flick) flick.contentY = 0;
  }
  function toggleModifier(name: string): void {
    const next = (root.modifiers || []).slice();
    const at = next.indexOf(name);
    if (at >= 0) next.splice(at, 1); else next.push(name);
    root.modifiers = next;
    Qt.callLater(root.scrollTop);
  }
  function clearFilters(): void {
    root.query = "";
    root.modifiers = [];
    Qt.callLater(root.scrollTop);
    if (root.active) root.forceActiveFocus();
  }
  function focusSearch(): void {
    searchField.forceActiveFocus();
    searchField.selectAll();
  }
  function handleEscape(): void {
    if (root.filtering) root.clearFilters();
    else root.closeRequested();
  }
  function accentFor(name: string): color {
    for (let index = 0; index < root.rail.length; index++) {
      if (root.rail[index].name === name) return root.tokens.accentAt(index);
    }
    return root.tokens.cyan;
  }
  function displayCount(name: string): int {
    if (name === "All") return root.visibleTotal;
    const found = root.filtered.find(category => category.name === name);
    return found ? found.entries.length : 0;
  }

  onActiveChanged: {
    if (root.active) root.reset();
  }
  onQueryChanged: {
    if (searchField && searchField.text !== root.query) searchField.text = root.query;
    Qt.callLater(root.scrollTop);
  }
  onModifiersChanged: Qt.callLater(root.scrollTop)
  onRailChanged: {
    if (root.categoryIndex >= root.rail.length) {
      root.categoryIndex = Math.max(0, root.rail.length - 1);
    }
  }

  Keys.onEscapePressed: function(event) {
    root.handleEscape();
    event.accepted = true;
  }
  Keys.onLeftPressed: function(event) {
    root.select(root.categoryIndex - 1);
    event.accepted = true;
  }
  Keys.onRightPressed: function(event) {
    root.select(root.categoryIndex + 1);
    event.accepted = true;
  }
  Keys.onTabPressed: function(event) {
    root.select(root.categoryIndex + 1);
    event.accepted = true;
  }
  Keys.onBacktabPressed: function(event) {
    root.select(root.categoryIndex - 1);
    event.accepted = true;
  }
  Keys.onUpPressed: function(event) {
    root.scroll(-72);
    event.accepted = true;
  }
  Keys.onDownPressed: function(event) {
    root.scroll(72);
    event.accepted = true;
  }
  Keys.onPressed: event => {
    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
      root.focusSearch();
      event.accepted = true;
      return;
    }
    if (searchField.activeFocus) return;

    if (event.key === Qt.Key_PageUp) { root.scroll(-flick.height * 0.8); event.accepted = true; return; }
    if (event.key === Qt.Key_PageDown) { root.scroll(flick.height * 0.8); event.accepted = true; return; }
    if (event.key === Qt.Key_Home) { root.scrollTop(); event.accepted = true; return; }
    if (event.key === Qt.Key_End) {
      if (flick) flick.contentY = Math.max(0, flick.contentHeight - flick.height);
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Backspace && root.query !== "") {
      root.query = root.query.slice(0, -1);
      event.accepted = true;
      return;
    }
    if (event.key === Qt.Key_Slash) {
      root.focusSearch();
      event.accepted = true;
      return;
    }
    if (event.text.length === 1 && event.text.charCodeAt(0) >= 0x20
        && event.text.charCodeAt(0) !== 0x7f
        && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
      root.query = root.query + event.text;
      root.focusSearch();
      event.accepted = true;
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: root.compact ? 18 : 26
    spacing: root.compact ? 10 : 13

    RowLayout {
      Layout.fillWidth: true
      spacing: root.compact ? 12 : 18

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2

        RowLayout {
          spacing: 7
          Text {
            text: "✦"
            color: root.tokens.cyan
            font {
              family: root.tokens.mono
              pixelSize: root.compact ? 9 : 10
            }
          }
          Text {
            text: "ASTRAL"
            color: root.tokens.cyan
            font {
              family: root.tokens.mono
              pixelSize: root.compact ? 8 : 9
              letterSpacing: 1.8
            }
          }
          Rectangle {
            implicitWidth: 1
            implicitHeight: 9
            color: Qt.alpha(root.tokens.muted, 0.3)
          }
          Text {
            text: "SHORTCUT ATLAS"
            color: Qt.alpha(root.tokens.muted, 0.85)
            font {
              family: root.tokens.mono
              pixelSize: root.compact ? 8 : 9
              letterSpacing: 1.5
            }
          }
        }

        Text {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          text: "Keyboard shortcuts"
          color: root.tokens.text
          elide: Text.ElideRight
          font {
            family: root.tokens.font
            pixelSize: root.compact ? 24 : 30
            weight: Font.DemiBold
            letterSpacing: -0.4
          }
        }

        Text {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          Layout.topMargin: 1
          text: root.subtitle
          textFormat: Text.PlainText
          color: root.subtitleColor
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          font {
            family: root.tokens.font
            pixelSize: root.compact ? 10 : 11
          }
        }
      }

      Rectangle {
        id: syncPill
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 2
        implicitWidth: syncRow.implicitWidth + 18
        implicitHeight: 26
        radius: 13
        color: Qt.alpha(root.syncColor, 0.1)
        border.width: 1
        border.color: Qt.alpha(root.syncColor, 0.3)

        RowLayout {
          id: syncRow
          anchors.centerIn: parent
          spacing: 6
          Rectangle {
            width: 6
            height: 6
            radius: 3
            color: root.syncColor
            SequentialAnimation on opacity {
              running: root.shortcuts.loading
              loops: Animation.Infinite
              NumberAnimation { from: 0.25; to: 1; duration: 800; easing.type: Easing.InOutQuad }
              NumberAnimation { from: 1; to: 0.25; duration: 800; easing.type: Easing.InOutQuad }
            }
          }
          Text {
            text: root.syncLabel
            color: root.syncColor
            font {
              family: root.tokens.mono
              pixelSize: 8
              weight: Font.DemiBold
              letterSpacing: 1.3
            }
          }
        }
      }

      Button {
        id: closeButton
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        padding: 0
        focusPolicy: Qt.NoFocus
        Accessible.name: "Close keyboard shortcuts"
        onClicked: root.closeRequested()
        contentItem: Text {
          text: "×"
          color: closeButton.hovered ? root.tokens.text : root.tokens.muted
          font.pixelSize: 22
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
          radius: 15
          color: closeButton.hovered ? Qt.alpha(root.tokens.muted, 0.12) : "transparent"
          border.width: 1
          border.color: closeButton.hovered ? Qt.alpha(root.tokens.muted, 0.18) : "transparent"
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 44
      radius: 12
      color: Qt.alpha(root.tokens.background, 0.35)
      border.width: 1
      border.color: searchField.activeFocus
        ? Qt.alpha(root.tokens.cyan, 0.55) : Qt.alpha(root.tokens.muted, 0.16)

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 13
        anchors.rightMargin: 8
        spacing: 8

        Item {
          Layout.preferredWidth: 14
          Layout.preferredHeight: 14
          Rectangle {
            width: 10
            height: 10
            radius: 5
            color: "transparent"
            border.width: 1
            border.color: searchField.activeFocus ? root.tokens.cyan : root.tokens.muted
          }
          Rectangle {
            x: 9
            y: 9
            width: 1
            height: 5
            radius: 0.5
            rotation: -45
            transformOrigin: Item.TopLeft
            color: searchField.activeFocus ? root.tokens.cyan : root.tokens.muted
          }
        }

        TextField {
          id: searchField
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          Layout.preferredHeight: 40
          placeholderText: "Search shortcuts, keys or categories…"
          placeholderTextColor: Qt.alpha(root.tokens.muted, 0.65)
          color: root.tokens.text
          selectByMouse: true
          activeFocusOnTab: false
          leftPadding: 0
          rightPadding: 0
          topPadding: 0
          bottomPadding: 0
          verticalAlignment: TextInput.AlignVCenter
          font {
            family: root.tokens.font
            pixelSize: root.compact ? 12 : 13
          }
          palette.text: root.tokens.text
          palette.highlight: Qt.alpha(root.tokens.cyan, 0.3)
          palette.highlightedText: root.tokens.text
          cursorDelegate: Rectangle {
            width: 1
            color: root.tokens.cyan
          }
          background: Item {}
          onTextChanged: if (root.query !== text) root.query = text
          onAccepted: root.forceActiveFocus()
          Keys.onEscapePressed: function(event) {
            root.handleEscape();
            event.accepted = true;
          }
          Keys.onDownPressed: function(event) {
            root.scroll(72);
            event.accepted = true;
          }
          Keys.onUpPressed: function(event) {
            root.scroll(-72);
            event.accepted = true;
          }
          Keys.onTabPressed: function(event) {
            root.select(root.categoryIndex + 1);
            event.accepted = true;
          }
          Keys.onBacktabPressed: function(event) {
            root.select(root.categoryIndex - 1);
            event.accepted = true;
          }
          Keys.onPressed: event => {
            if (event.key === Qt.Key_PageDown) {
              root.scroll(flick.height * 0.8);
              event.accepted = true;
            } else if (event.key === Qt.Key_PageUp) {
              root.scroll(-flick.height * 0.8);
              event.accepted = true;
            }
          }
        }

        Button {
          id: clearButton
          visible: root.query !== ""
          Layout.preferredWidth: 24
          Layout.preferredHeight: 24
          padding: 0
          focusPolicy: Qt.NoFocus
          Accessible.name: "Clear search"
          onClicked: {
            root.query = "";
            searchField.forceActiveFocus();
          }
          contentItem: Text {
            text: "×"
            color: clearButton.hovered ? root.tokens.text : root.tokens.muted
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            radius: 12
            color: clearButton.hovered ? Qt.alpha(root.tokens.muted, 0.12) : "transparent"
          }
        }

        Text {
          visible: root.query === ""
          text: "/"
          color: Qt.alpha(root.tokens.muted, 0.55)
          font {
            family: root.tokens.mono
            pixelSize: 9
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Text {
        text: "MODIFIERS"
        color: Qt.alpha(root.tokens.muted, 0.85)
        Layout.rightMargin: 3
        font {
          family: root.tokens.mono
          pixelSize: 8
          letterSpacing: 1.3
        }
      }

      Repeater {
        model: Logic.modifierChips
        delegate: Button {
          id: chip
          required property var modelData
          readonly property bool activeChip: root.modifiers.indexOf(chip.modelData) >= 0
          Layout.preferredHeight: 26
          leftPadding: 10
          rightPadding: 10
          topPadding: 0
          bottomPadding: 0
          focusPolicy: Qt.NoFocus
          Accessible.name: "Filter by " + chip.modelData
          onClicked: {
            root.toggleModifier(chip.modelData);
            root.forceActiveFocus();
          }
          contentItem: Text {
            text: chip.modelData
            color: chip.activeChip ? root.tokens.surface : root.tokens.muted
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font {
              family: root.tokens.mono
              pixelSize: 9
              weight: Font.DemiBold
              letterSpacing: 0.4
            }
          }
          background: Rectangle {
            radius: 13
            color: chip.activeChip ? root.tokens.cyan
              : chip.hovered ? Qt.alpha(root.tokens.muted, 0.1) : "transparent"
            border.width: 1
            border.color: chip.activeChip ? root.tokens.cyan : Qt.alpha(root.tokens.muted, 0.2)
          }
        }
      }

      Item { Layout.fillWidth: true }

      Text {
        text: root.filtering
          ? root.visibleTotal + (root.visibleTotal === 1 ? " match" : " matches")
          : root.shortcuts.total + (root.shortcuts.total === 1 ? " binding" : " bindings")
        color: root.filtering ? root.tokens.cyan : Qt.alpha(root.tokens.muted, 0.8)
        font {
          family: root.tokens.mono
          pixelSize: 9
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: root.compact ? 14 : 20

      ColumnLayout {
        Layout.preferredWidth: root.compact ? 168 : 204
        Layout.maximumWidth: root.compact ? 168 : 204
        Layout.fillHeight: true
        spacing: 4

        Text {
          text: "LIBRARY"
          Layout.bottomMargin: 4
          color: Qt.alpha(root.tokens.muted, 0.9)
          font {
            family: root.tokens.mono
            pixelSize: 8
            letterSpacing: 1.5
          }
        }

        Flickable {
          id: navFlick
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          contentWidth: width
          contentHeight: navColumn.implicitHeight
          ScrollBar.vertical: ScrollBar {
            policy: navFlick.contentHeight > navFlick.height + 1
              ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            width: 4
            contentItem: Rectangle {
              implicitWidth: 4
              radius: 2
              color: Qt.alpha(root.tokens.muted, 0.3)
            }
            background: Item {}
          }

          Column {
            id: navColumn
            width: navFlick.width
            spacing: 4

            Repeater {
              model: root.rail
              delegate: Button {
                id: categoryButton
                required property var modelData
                required property int index
                readonly property bool current: root.categoryIndex === categoryButton.index
                readonly property color accent: root.accentFor(categoryButton.modelData.name)
                readonly property int shownCount: root.displayCount(categoryButton.modelData.name)
                width: navColumn.width
                height: root.compact ? 30 : 34
                padding: 0
                focusPolicy: Qt.NoFocus
                Accessible.name: categoryButton.modelData.name + " shortcuts"
                enabled: !root.filtering || categoryButton.modelData.name === "All"
                  || categoryButton.shownCount > 0
                onClicked: {
                  root.select(categoryButton.index);
                  root.forceActiveFocus();
                }

                background: Item {}

                contentItem: Item {
                  Rectangle {
                    anchors.fill: parent
                    radius: 9
                    color: categoryButton.current
                      ? Qt.alpha(categoryButton.accent, 0.12)
                      : categoryButton.hovered && categoryButton.enabled
                        ? Qt.alpha(root.tokens.muted, 0.06) : "transparent"
                    border.width: 1
                    border.color: categoryButton.current
                      ? Qt.alpha(categoryButton.accent, 0.35) : "transparent"
                  }
                  Rectangle {
                    visible: categoryButton.current
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 3
                    height: 16
                    radius: 1.5
                    color: categoryButton.accent
                  }
                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: categoryButton.current ? 11 : 9
                    anchors.rightMargin: 9
                    spacing: 8
                    Text {
                      text: categoryButton.modelData.glyph
                      color: categoryButton.current ? categoryButton.accent
                        : Qt.alpha(root.tokens.text, 0.62)
                      Layout.preferredWidth: 21
                      opacity: categoryButton.enabled ? 1 : 0.4
                      font {
                        family: root.tokens.mono
                        pixelSize: root.compact ? 15 : 17
                        weight: Font.DemiBold
                      }
                    }
                    Text {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 0
                      text: categoryButton.modelData.name
                      elide: Text.ElideRight
                      color: categoryButton.current ? root.tokens.text : root.tokens.muted
                      opacity: categoryButton.enabled ? 1 : 0.45
                      font {
                        family: root.tokens.font
                        pixelSize: root.compact ? 10 : 11
                        weight: categoryButton.current ? Font.DemiBold : Font.Normal
                      }
                    }
                    Text {
                      text: categoryButton.shownCount
                      color: categoryButton.current
                        ? categoryButton.accent : Qt.alpha(root.tokens.muted, 0.75)
                      opacity: categoryButton.enabled ? 1 : 0.4
                      font {
                        family: root.tokens.mono
                        pixelSize: 9
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: sourceColumn.implicitHeight + 20
          radius: 11
          color: Qt.alpha(root.tokens.muted, 0.04)
          border.width: 1
          border.color: Qt.alpha(root.tokens.muted, 0.1)

          ColumnLayout {
            id: sourceColumn
            anchors.fill: parent
            anchors.margins: 10
            spacing: 3

            RowLayout {
              spacing: 6
              Rectangle {
                width: 5
                height: 5
                radius: 2.5
                color: root.syncColor
              }
              Text {
                text: "LIVE SOURCE"
                color: root.syncColor
                font {
                  family: root.tokens.mono
                  pixelSize: 8
                  letterSpacing: 1.2
                }
              }
            }
            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              text: "hyprctl -j binds"
              color: Qt.alpha(root.tokens.text, 0.85)
              elide: Text.ElideRight
              font {
                family: root.tokens.mono
                pixelSize: root.compact ? 9 : 10
              }
            }
            Text {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              visible: !root.compact
              text: "Refreshed every time this panel opens."
              color: Qt.alpha(root.tokens.muted, 0.8)
              wrapMode: Text.Wrap
              font {
                family: root.tokens.font
                pixelSize: 9
              }
            }
          }
        }
      }

      Rectangle {
        Layout.fillHeight: true
        implicitWidth: 1
        color: root.tokens.hairline
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true

          Flickable {
            id: flick
            anchors.fill: parent
            clip: true
            focus: false
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            contentWidth: width
            contentHeight: Math.max(root.listMode ? singleColumn.implicitHeight : atlas.implicitHeight, height)
            ScrollBar.vertical: ScrollBar {
              policy: flick.contentHeight > flick.height + 1 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
              width: 6
              contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: Qt.alpha(root.tokens.muted, 0.32)
              }
              background: Item {}
            }

            Column {
              id: singleColumn
              width: flick.width
              y: root.listMode && singleColumn.implicitHeight < flick.height
                ? Math.round((flick.height - singleColumn.implicitHeight) / 2) : 0
              spacing: root.cardGap
              visible: root.listMode
              Repeater {
                model: root.listMode ? root.display : []
                delegate: ShortcutCard {
                  required property var modelData
                  width: parent.width
                  tokens: root.tokens
                  category: modelData
                  accent: root.accentFor(modelData.name)
                  columns: root.entryColumns
                  compact: root.compact
                }
              }
            }

            Row {
              id: atlas
              width: flick.width
              spacing: root.cardGap
              visible: !root.listMode
              readonly property real columnWidth: Math.max(1, (width - spacing) / 2)

              Column {
                width: atlas.columnWidth
                spacing: root.cardGap
                Repeater {
                  model: root.listMode ? [] : root.masonry.left
                  delegate: ShortcutCard {
                    required property var modelData
                    width: parent.width
                    tokens: root.tokens
                    category: modelData
                    accent: root.accentFor(modelData.name)
                    columns: 1
                    compact: root.compact
                  }
                }
              }

              Column {
                width: atlas.columnWidth
                spacing: root.cardGap
                Repeater {
                  model: root.listMode ? [] : root.masonry.right
                  delegate: ShortcutCard {
                    required property var modelData
                    width: parent.width
                    tokens: root.tokens
                    category: modelData
                    accent: root.accentFor(modelData.name)
                    columns: 1
                    compact: root.compact
                  }
                }
              }
            }
          }

          ColumnLayout {
            id: loadingState
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 380)
            spacing: 8
            visible: root.shortcuts.loading && root.shortcuts.categories.length === 0

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "✦"
              color: root.tokens.cyan
              font {
                family: root.tokens.mono
                pixelSize: 26
              }
              SequentialAnimation on opacity {
                running: loadingState.visible && root.tokens.entryDuration > 0
                loops: Animation.Infinite
                NumberAnimation { from: 0.25; to: 1; duration: 850; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1; to: 0.25; duration: 850; easing.type: Easing.InOutQuad }
              }
            }
            Text {
              Layout.fillWidth: true
              text: "Reading active bindings…"
              color: root.tokens.muted
              horizontalAlignment: Text.AlignHCenter
              font {
                family: root.tokens.font
                pixelSize: 12
              }
            }
            Text {
              Layout.fillWidth: true
              text: "hyprctl -j binds"
              color: Qt.alpha(root.tokens.muted, 0.6)
              horizontalAlignment: Text.AlignHCenter
              font {
                family: root.tokens.mono
                pixelSize: 9
              }
            }
          }

          ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 400)
            spacing: 8
            visible: !root.shortcuts.loading && root.shortcuts.error !== ""
              && root.shortcuts.categories.length === 0

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "!"
              color: root.tokens.alert
              font {
                family: root.tokens.mono
                pixelSize: 24
                weight: Font.DemiBold
              }
            }
            Text {
              Layout.fillWidth: true
              text: root.shortcuts.error
              color: root.tokens.alert
              wrapMode: Text.Wrap
              horizontalAlignment: Text.AlignHCenter
              font {
                family: root.tokens.font
                pixelSize: 12
              }
            }
            Text {
              Layout.fillWidth: true
              text: "Check that Hyprland is running and hyprctl is available."
              color: root.tokens.muted
              wrapMode: Text.Wrap
              horizontalAlignment: Text.AlignHCenter
              font {
                family: root.tokens.font
                pixelSize: 10
              }
            }
          }

          ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 360)
            spacing: 7
            visible: !root.shortcuts.loading && root.shortcuts.error === ""
              && root.shortcuts.categories.length === 0 && root.shortcuts.total === 0

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "∅"
              color: Qt.alpha(root.tokens.muted, 0.75)
              font {
                family: root.tokens.mono
                pixelSize: 24
              }
            }
            Text {
              Layout.fillWidth: true
              text: "No active bindings found."
              color: root.tokens.muted
              horizontalAlignment: Text.AlignHCenter
              font {
                family: root.tokens.font
                pixelSize: 12
              }
            }
          }

          ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 380)
            spacing: 8
            visible: root.emptyView

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: root.selected === "All" ? "⌕" : "∅"
              color: Qt.alpha(root.tokens.muted, 0.75)
              font {
                family: root.tokens.mono
                pixelSize: 24
              }
            }
            Text {
              Layout.fillWidth: true
              text: root.selected === "All"
                ? "Nothing matches your search."
                : "No shortcuts in " + root.selected + " match."
              color: root.tokens.text
              wrapMode: Text.Wrap
              horizontalAlignment: Text.AlignHCenter
              font {
                family: root.tokens.font
                pixelSize: 12
                weight: Font.DemiBold
              }
            }
            Text {
              Layout.fillWidth: true
              text: "Try another term, remove a modifier or show all categories."
              color: root.tokens.muted
              wrapMode: Text.Wrap
              horizontalAlignment: Text.AlignHCenter
              font {
                family: root.tokens.font
                pixelSize: 10
              }
            }
            Button {
              Layout.alignment: Qt.AlignHCenter
              Layout.topMargin: 3
              implicitWidth: resetText.implicitWidth + 24
              implicitHeight: 28
              padding: 0
              focusPolicy: Qt.NoFocus
              onClicked: {
                root.clearFilters();
                root.select(0);
              }
              contentItem: Text {
                id: resetText
                text: "Show all shortcuts"
                color: root.tokens.cyan
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font {
                  family: root.tokens.font
                  pixelSize: 10
                  weight: Font.DemiBold
                }
              }
              background: Rectangle {
                radius: 14
                color: Qt.alpha(root.tokens.cyan, 0.1)
                border.width: 1
                border.color: Qt.alpha(root.tokens.cyan, 0.3)
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 1
          color: Qt.alpha(root.tokens.muted, 0.1)
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.topMargin: 8
          spacing: 10

          Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.narrow
              ? "↑↓ scroll · ←→ categories · / search · Esc close"
              : "↑ ↓ scroll · ← → categories · Tab next · type or / to search · Esc clears, then closes"
            color: Qt.alpha(root.tokens.muted, 0.75)
            elide: Text.ElideRight
            font {
              family: root.tokens.mono
              pixelSize: 9
            }
          }

          Text {
            text: "hyprctl · live"
            color: Qt.alpha(root.tokens.muted, 0.75)
            font {
              family: root.tokens.mono
              pixelSize: 9
            }
          }
        }
      }
    }
  }
}
