pragma ComponentBehavior: Bound
import "data" as CommonShortcuts
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Logic.js" as Logic
import "../common" as Common

FocusScope {
  id: root
  required property var tokens
  property bool active: false
  property int categoryIndex: 0
  property string query: ""
  property var modifiers: []
  focus: root.active

  property var shortcuts: CommonShortcuts.ShortcutsData
  readonly property bool compact: width < 900 || height < 590
  readonly property bool narrow: width < 780
  readonly property bool filtering: root.query.trim() !== "" || root.modifiers.length > 0
  readonly property int cardGap: root.compact ? 12 : 16
  readonly property int entryColumns: width >= 960 ? 2 : 1

  readonly property var rail: Logic.railFor(root.shortcuts.categories, root.shortcuts.total)
  readonly property string selected: root.rail.length > 0
    ? root.rail[Logic.clampIndex(root.categoryIndex, root.rail.length)].name : "All"
  readonly property var filtered: Logic.filterCategories(root.shortcuts.categories, root.query, root.modifiers)
  readonly property var display: root.selected === "All"
    ? root.filtered
    : root.filtered.filter(category => category.name === root.selected)
  readonly property int visibleTotal: Logic.countEntries(root.filtered)
  readonly property int displayTotal: Logic.countEntries(root.display)
  readonly property bool single: root.selected !== "All" || root.filtering
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
    anchors.margins: root.compact ? 16 : 24
    spacing: root.compact ? 12 : 16

    RowLayout {
      Layout.fillWidth: true
      spacing: root.compact ? 12 : 16

      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 4

        RowLayout {
          spacing: 8
          Text {
            text: "✦"
            color: root.tokens.cyan
            font {
              family: root.tokens.mono
              pixelSize: 11
            }
          }
          Text {
            text: "ASTRAL"
            color: root.tokens.cyan
            font {
              family: root.tokens.mono
              pixelSize: 10
              weight: Font.DemiBold
              letterSpacing: 1.6
            }
          }
          Rectangle {
            implicitWidth: 1
            implicitHeight: 10
            color: root.tokens.border
          }
          Text {
            text: "HYPRLAND"
            color: root.tokens.muted
            font {
              family: root.tokens.mono
              pixelSize: 10
              letterSpacing: 1.4
            }
          }
        }

        Text {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          text: "Your keyboard, at a glance"
          color: root.tokens.text
          elide: Text.ElideRight
          font {
            family: root.tokens.font
            pixelSize: root.compact ? 20 : 26
            weight: Font.DemiBold
          }
        }

        Text {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          text: root.subtitle
          textFormat: Text.PlainText
          color: root.subtitleColor
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          font {
            family: root.tokens.font
            pixelSize: 12
          }
        }
      }

      Rectangle {
        id: syncPill
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: 4
        implicitWidth: syncRow.implicitWidth + 24
        implicitHeight: 26
        radius: height / 2
        color: Qt.alpha(root.syncColor, 0.12)
        border.width: 1
        border.color: Qt.alpha(root.syncColor, 0.4)

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
              pixelSize: 10
              weight: Font.DemiBold
              letterSpacing: 1.2
            }
          }
        }
      }

      Button {
        id: closeButton
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        padding: 0
        focusPolicy: Qt.NoFocus
        Accessible.name: "Close keyboard shortcuts"
        onClicked: root.closeRequested()
        contentItem: Text {
          text: "×"
          color: closeButton.hovered ? root.tokens.text : root.tokens.muted
          font.pixelSize: 20
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
          radius: height / 2
          color: closeButton.hovered ? root.tokens.raised : "transparent"
          border.width: 1
          border.color: closeButton.hovered ? root.tokens.border : "transparent"
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 44
      radius: root.tokens.rowRadius
      color: root.tokens.sunken
      border.width: searchField.activeFocus ? 2 : 1
      border.color: searchField.activeFocus
        ? Qt.alpha(root.tokens.cyan, 0.7) : root.tokens.border

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        spacing: 10

        Item {
          Layout.preferredWidth: 14
          Layout.preferredHeight: 14
          Rectangle {
            width: 10
            height: 10
            radius: 5
            color: "transparent"
            border.width: 1.4
            border.color: searchField.activeFocus ? root.tokens.cyan : root.tokens.muted
          }
          Rectangle {
            x: 9
            y: 9
            width: 1.4
            height: 5
            radius: 0.7
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
          placeholderTextColor: root.tokens.muted
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
          Layout.preferredWidth: 26
          Layout.preferredHeight: 26
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
            radius: height / 2
            color: clearButton.hovered ? root.tokens.raised : "transparent"
          }
        }

        Rectangle {
          visible: root.query === ""
          implicitWidth: slashKey.implicitWidth + 12
          implicitHeight: 20
          radius: 5
          color: root.tokens.raised
          border.width: 1
          border.color: root.tokens.border
          Text {
            id: slashKey
            anchors.centerIn: parent
            text: "/"
            color: root.tokens.muted
            font {
              family: root.tokens.mono
              pixelSize: 10
              weight: Font.DemiBold
            }
          }
        }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Text {
        text: "MODIFIERS"
        color: root.tokens.muted
        Layout.rightMargin: 4
        font {
          family: root.tokens.mono
          pixelSize: 10
          letterSpacing: 1.2
        }
      }

      Repeater {
        model: Logic.modifierChips
        delegate: Button {
          id: chip
          required property var modelData
          readonly property bool activeChip: root.modifiers.indexOf(chip.modelData) >= 0
          Layout.preferredHeight: 26
          leftPadding: 12
          rightPadding: 12
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
              pixelSize: 10
              weight: Font.DemiBold
              letterSpacing: 0.4
            }
          }
          background: Rectangle {
            radius: height / 2
            color: chip.activeChip ? root.tokens.cyan
              : chip.hovered ? root.tokens.raised : "transparent"
            border.width: 1
            border.color: chip.activeChip ? root.tokens.cyan
              : chip.hovered ? root.tokens.border : Qt.alpha(root.tokens.muted, 0.3)
          }
        }
      }

      Item { Layout.fillWidth: true }

      Text {
        text: root.filtering
          ? root.visibleTotal + (root.visibleTotal === 1 ? " match" : " matches")
          : root.shortcuts.total + (root.shortcuts.total === 1 ? " binding" : " bindings")
        color: root.filtering ? root.tokens.cyan : root.tokens.muted
        font {
          family: root.tokens.mono
          pixelSize: 10
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 0
      spacing: 16

      Flow {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        spacing: 6
        Repeater {
          model: root.rail
          delegate: Button {
            id: categoryButton
            required property var modelData
            required property int index
            readonly property bool current: root.categoryIndex === index
            text: modelData.name + "  " + root.displayCount(modelData.name)
            implicitHeight: 32
            leftPadding: 14; rightPadding: 14
            focusPolicy: Qt.NoFocus
            Accessible.name: modelData.name + " shortcuts"
            onClicked: { root.select(index); root.forceActiveFocus(); }
            contentItem: Text {
              text: categoryButton.text
              color: categoryButton.current ? root.tokens.background : root.tokens.muted
              font { family: root.tokens.font; pixelSize: 12; weight: Font.Medium }
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
              radius: 8
              color: categoryButton.current ? root.tokens.cyan
                : categoryButton.hovered ? root.tokens.raised : root.tokens.sunken
              border.color: categoryButton.current ? "transparent" : root.tokens.hairline
            }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumWidth: 0
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
            contentHeight: Math.max(singleColumn.implicitHeight, height)
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
              width: flick.width - 12
              spacing: root.cardGap
              Repeater {
                model: root.display
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
              text: "Please wait a moment"
              color: root.tokens.muted
              horizontalAlignment: Text.AlignHCenter
              font {
                family: root.tokens.mono
                pixelSize: 10
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
                pixelSize: 11
              }
            }
          }

          ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 48, 360)
            spacing: 8
            visible: !root.shortcuts.loading && root.shortcuts.error === ""
              && root.shortcuts.categories.length === 0 && root.shortcuts.total === 0

            Text {
              Layout.alignment: Qt.AlignHCenter
              text: "∅"
              color: root.tokens.muted
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
              color: root.tokens.muted
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
                pixelSize: 13
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
                pixelSize: 11
              }
            }
            Button {
              Layout.alignment: Qt.AlignHCenter
              Layout.topMargin: 4
              implicitWidth: resetText.implicitWidth + 28
              implicitHeight: 30
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
                  pixelSize: 11
                  weight: Font.DemiBold
                }
              }
              background: Rectangle {
                radius: height / 2
                color: Qt.alpha(root.tokens.cyan, 0.12)
                border.width: 1
                border.color: Qt.alpha(root.tokens.cyan, 0.4)
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: 1
          color: root.tokens.hairline
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
            color: root.tokens.muted
            elide: Text.ElideRight
            font {
              family: root.tokens.mono
              pixelSize: 10
            }
          }

          Text {
            text: "Hyprland"
            color: root.tokens.muted
            font {
              family: root.tokens.mono
              pixelSize: 10
            }
          }
        }
      }
    }
  }
}
