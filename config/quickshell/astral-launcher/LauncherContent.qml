pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "Logic.js" as Logic

FocusScope {
  id: root
  required property var service
  required property var tokens
  property string category: "Home"
  readonly property bool compact: width < 720 || height < 500
  readonly property bool searching: search.text.trim().length > 0
  readonly property var homeEntries: Logic.select(service.entries, service.state, "Home", "")
  readonly property var results: Logic.select(service.entries, service.state,
    category === "Home" && homeEntries.length === 0 ? "All" : category, search.text)
  readonly property var selected: grid.currentIndex >= 0 && grid.currentIndex < results.length ? results[grid.currentIndex] : null
  readonly property var sections: [
    { key: "Home", label: "Discover", glyph: "⌂", detail: "Your everyday essentials" },
    { key: "Favorites", label: "Favorites", glyph: "☆", detail: "Always within reach" },
    { key: "Frequent", label: "Frequent", glyph: "◷", detail: "Your most used apps" },
    { key: "All", label: "All apps", glyph: "", detail: "Explore your collection" }
  ]
  signal closeRequested()
  onCategoryChanged: resultsEntrance.restart()
  ParallelAnimation {
    id: resultsEntrance
    NumberAnimation { target: grid; property: "opacity"; from: 0.35; to: 1; duration: root.tokens.entryDuration; easing.type: Easing.OutCubic }
    NumberAnimation { target: grid; property: "translation"; from: 8; to: 0; duration: root.tokens.entryDuration; easing.type: Easing.OutCubic }
  }
  function reset() {
    search.text = ""; category = "Home"; grid.currentIndex = 0;
    service.error = ""; grid.positionViewAtBeginning(); search.forceActiveFocus();
  }
  function activate() { if (selected) service.launch(selected); }
  function choose(key) { category = key; grid.currentIndex = 0; grid.positionViewAtBeginning(); search.forceActiveFocus(); }
  Keys.onEscapePressed: closeRequested()
  Keys.onPressed: event => {
    if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
      if (selected) service.pin(selected);
      event.accepted = true;
    }
  }

  RowLayout {
    anchors.fill: parent
    spacing: 0
    Rectangle {
      visible: !root.compact
      Layout.preferredWidth: 208
      Layout.fillHeight: true
      color: root.tokens.background
      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 8
        RowLayout {
          spacing: 10
          Rectangle {
            Layout.preferredWidth: 36; Layout.preferredHeight: 36
            radius: 12; color: Qt.alpha(root.tokens.cyan, 0.12)
            Text {
              anchors.centerIn: parent
              text: "✦"
              color: root.tokens.cyan
              font.pixelSize: 28
            }
          }
          ColumnLayout {
            spacing: 1
            Text { text: "ASTRAL"; color: root.tokens.text; font.family: root.tokens.font; font.pixelSize: 15; font.weight: Font.DemiBold; font.letterSpacing: 2 }
            Text { text: "APP LIBRARY"; color: root.tokens.muted; font.pixelSize: 8; font.letterSpacing: 1 }
          }
        }
        Item { Layout.preferredHeight: 36 }
        Text { text: "YOUR SPACE"; color: root.tokens.muted; font.pixelSize: 9; font.letterSpacing: 1.8; Layout.bottomMargin: 8 }
        Repeater {
          model: root.sections
          delegate: Button {
            id: section
            required property var modelData
            readonly property bool selected: root.category === modelData.key
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            leftPadding: 12; rightPadding: 10
            onClicked: root.choose(modelData.key)
            contentItem: RowLayout {
              spacing: 12
              Item {
                Layout.preferredWidth: 22; Layout.preferredHeight: 22
                Text {
                  anchors.centerIn: parent
                  visible: section.modelData.key !== "All"
                  text: section.modelData.glyph; color: section.selected ? root.tokens.cyan : root.tokens.muted; font.pixelSize: 21
                }
                Grid {
                  anchors.centerIn: parent
                  visible: section.modelData.key === "All"
                  columns: 2; spacing: 3
                  Repeater {
                    model: 4
                    Rectangle {
                      width: 7; height: 7; radius: 2
                      color: section.selected ? root.tokens.cyan : root.tokens.muted
                      Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
                    }
                  }
                }
              }
              Text { text: section.modelData.label; color: section.selected ? root.tokens.text : root.tokens.muted; font.family: root.tokens.font; font.pixelSize: 13; font.weight: section.selected ? Font.DemiBold : Font.Normal; Layout.fillWidth: true }
              Rectangle { Layout.preferredWidth: 4; Layout.preferredHeight: 4; radius: 2; visible: section.selected; color: root.tokens.cyan }
            }
            background: Rectangle {
              radius: 10
              color: section.selected ? Qt.alpha(root.tokens.cyan, 0.12) : section.hovered ? Qt.alpha(root.tokens.muted, 0.07) : "transparent"
              border.color: section.activeFocus ? root.tokens.cyan : "transparent"
              Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
            }
            scale: down ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: root.tokens.hoverDuration; easing.type: Easing.OutCubic } }
          }
        }
        Item { Layout.fillHeight: true }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.tokens.border }
        Text { text: root.service.entries.filter(e => !e.noDisplay).length + " apps, one place."; color: root.tokens.muted; font.family: root.tokens.font; font.pixelSize: 11; Layout.topMargin: 10 }
      }
    }
    Rectangle { visible: !root.compact; Layout.fillHeight: true; Layout.preferredWidth: 1; color: root.tokens.border }
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.margins: root.compact ? 16 : 28
      spacing: root.compact ? 12 : 18
      RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 4
          Text {
            text: root.searching ? "Search results" : root.category === "Home" ? "Your applications" : root.sections.find(s => s.key === root.category).label
            color: root.tokens.text; font.family: root.tokens.font; font.pixelSize: root.compact ? 22 : 28; font.weight: Font.DemiBold
            Layout.fillWidth: true; elide: Text.ElideRight
          }
          Text {
            visible: !root.compact
            text: root.searching ? "Find an app and press Enter to open it." : root.category === "Home" ? "Favorites and familiar places, a little closer." : root.sections.find(s => s.key === root.category).detail
            color: root.tokens.muted; font.family: root.tokens.font; font.pixelSize: 12
          }
        }
        Button {
          id: closeButton
          Layout.preferredWidth: 32; Layout.preferredHeight: 32
          Accessible.name: "Close launcher"
          onClicked: root.closeRequested()
          contentItem: Text { text: "×"; color: root.tokens.muted; font.pixelSize: 23; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
          background: Rectangle { radius: 16; color: closeButton.hovered ? Qt.alpha(root.tokens.muted, 0.12) : "transparent"; border.color: closeButton.activeFocus ? root.tokens.cyan : root.tokens.border }
        }
      }
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.compact ? 48 : 58
        radius: 14
        color: root.tokens.background
        border.color: search.activeFocus ? Qt.alpha(root.tokens.cyan, 0.65) : root.tokens.border
        Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
        RowLayout {
          anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 12
          spacing: 12
          Item {
            Layout.preferredWidth: 20; Layout.preferredHeight: 20
            Rectangle {
              x: 2; y: 2; width: 12; height: 12; radius: 6
              color: "transparent"; border.width: 1.6; border.color: root.tokens.cyan
            }
            Rectangle {
              x: 13; y: 12; width: 7; height: 1.6; rotation: 45
              transformOrigin: Item.Left; radius: 1; color: root.tokens.cyan
            }
          }
          TextField {
            id: search
            Layout.fillWidth: true; Layout.fillHeight: true
            padding: 0
            placeholderText: "Search your applications"
            Accessible.name: "Search applications"
            color: root.tokens.text; placeholderTextColor: root.tokens.muted
            font.family: root.tokens.font; font.pixelSize: 14
            selectByMouse: true
            background: Item {}
            onTextChanged: { grid.currentIndex = 0; grid.positionViewAtBeginning(); }
            Keys.onDownPressed: { if (root.results.length) { grid.forceActiveFocus(); grid.currentIndex = Math.max(0, grid.currentIndex); } }
            Keys.onPressed: event => {
              if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
                if (root.selected) root.service.pin(root.selected);
                event.accepted = true;
              }
            }
            onAccepted: root.activate()
          }
          Button {
            id: clearButton
            visible: root.searching
            Layout.preferredWidth: 28; Layout.preferredHeight: 28
            Accessible.name: "Clear search"
            onClicked: { search.clear(); search.forceActiveFocus(); }
            contentItem: Text { text: "×"; color: root.tokens.muted; font.pixelSize: 19; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 8; color: clearButton.hovered ? Qt.alpha(root.tokens.muted, 0.12) : "transparent"; border.color: clearButton.activeFocus ? root.tokens.cyan : "transparent" }
          }
        }
      }
      RowLayout {
        visible: root.compact
        Layout.fillWidth: true
        spacing: 4
        Repeater {
          model: root.sections
          delegate: Button {
            id: compactSection
            required property var modelData
            Layout.fillWidth: true; Layout.preferredHeight: 30
            onClicked: root.choose(modelData.key)
            contentItem: Text { text: compactSection.modelData.label; color: root.category === compactSection.modelData.key ? root.tokens.cyan : root.tokens.muted; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 8; color: root.category === compactSection.modelData.key ? Qt.alpha(root.tokens.cyan, 0.1) : "transparent"; border.color: compactSection.activeFocus ? root.tokens.cyan : "transparent" }
          }
        }
      }
      Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.service.error || root.service.warning
        color: root.service.error ? root.tokens.alert : root.tokens.gold
        wrapMode: Text.Wrap; font.pixelSize: 11
      }
      RowLayout {
        Layout.fillWidth: true
        Text {
          text: root.searching ? "SEARCH RESULTS" : root.category === "Home" ? (root.homeEntries.length ? "PICK UP WHERE YOU LEFT OFF" : "EXPLORE YOUR APPS") : root.category.toUpperCase()
          color: root.tokens.muted; font.pixelSize: 9; font.letterSpacing: 1.4
          Layout.fillWidth: true; elide: Text.ElideRight
        }
        Text { text: root.results.length.toString().padStart(2, "0"); color: root.tokens.cyan; font.family: root.tokens.mono; font.pixelSize: 11 }
      }
      GridView {
        id: grid
        property real translation: 0
        transform: Translate { y: grid.translation }
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true
        model: root.results
        cellWidth: width / Math.max(1, Math.floor(width / (root.compact ? 116 : 144)))
        cellHeight: root.compact ? 116 : 150
        keyNavigationEnabled: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Keys.onReturnPressed: root.activate()
        Keys.onEnterPressed: root.activate()
        Keys.onUpPressed: event => {
          if (currentIndex < Math.round(width / cellWidth)) search.forceActiveFocus();
          else event.accepted = false;
        }
        delegate: Item {
          id: tile
          required property var modelData
          required property int index
          readonly property bool selected: grid.currentIndex === index
          readonly property bool pinned: root.service.state.favorites.includes(Logic.identity(modelData))
          width: grid.cellWidth; height: grid.cellHeight
          Rectangle {
            anchors.fill: parent; anchors.margins: 4
            radius: 16
            color: tile.selected ? Qt.alpha(root.tokens.cyan, 0.10) : hover.hovered ? Qt.alpha(root.tokens.muted, 0.06) : Qt.alpha(root.tokens.background, 0.45)
            border.color: tile.selected ? Qt.alpha(root.tokens.cyan, grid.activeFocus ? 0.85 : 0.45) : hover.hovered ? Qt.alpha(root.tokens.muted, 0.3) : Qt.alpha(root.tokens.border, 0.4)
            Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
            Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { grid.currentIndex = tile.index; grid.forceActiveFocus(); root.service.launch(tile.modelData); }
            }
          }
          HoverHandler { id: hover }
          Rectangle {
            id: iconWell
            anchors.horizontalCenter: parent.horizontalCenter
            y: root.compact ? 12 : 18
            transform: Translate { y: hover.hovered ? -3 : 0; Behavior on y { NumberAnimation { duration: root.tokens.hoverDuration; easing.type: Easing.OutCubic } } }
            scale: hover.hovered ? 1.06 : 1
            Behavior on scale { NumberAnimation { duration: root.tokens.hoverDuration; easing.type: Easing.OutCubic } }
            width: root.compact ? 48 : 64; height: width
            radius: root.compact ? 14 : 18
            color: Qt.alpha(root.tokens.cyan, tile.selected || hover.hovered ? 0.10 : 0.045)
            Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
            Image {
              id: icon
              anchors.centerIn: parent
              width: root.compact ? 32 : 44; height: width
              source: Quickshell.iconPath(tile.modelData.icon || "application-x-executable", "application-x-executable")
              fillMode: Image.PreserveAspectFit
              asynchronous: true
            }
            Text { anchors.centerIn: parent; visible: icon.status !== Image.Ready; text: "◇"; color: root.tokens.cyan; font.pixelSize: 30 }
          }
          Text {
            x: 12; y: root.compact ? 66 : 94; width: parent.width - 24
            text: tile.modelData.name; color: root.tokens.text
            font.family: root.tokens.font; font.pixelSize: root.compact ? 11 : 12; font.weight: Font.Medium
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
          }
          Text {
            x: 12; y: root.compact ? 84 : 115; width: parent.width - 24
            text: Logic.identity(tile.modelData).replace(/\.desktop$/, "")
            color: root.tokens.muted; opacity: 0.85
            font.pixelSize: 9; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle
          }
          Button {
            id: pin
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
            width: 26; height: 26
            opacity: tile.pinned || hover.hovered || tile.selected || activeFocus ? 1 : 0
            Accessible.name: (tile.pinned ? "Unpin " : "Pin ") + tile.modelData.name
            ToolTip.visible: hovered
            ToolTip.text: tile.pinned ? "Remove from favorites" : "Add to favorites"
            onClicked: root.service.pin(tile.modelData)
            contentItem: Text { text: tile.pinned ? "★" : "☆"; color: tile.pinned ? root.tokens.gold : root.tokens.muted; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 8; color: pin.hovered ? root.tokens.background : "transparent"; border.color: pin.activeFocus ? root.tokens.cyan : "transparent" }
            Behavior on opacity { NumberAnimation { duration: root.tokens.hoverDuration } }
          }
        }
        Column {
          anchors.centerIn: parent
          width: Math.max(0, parent.width - 32)
          spacing: 12
          visible: root.results.length === 0
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.searching ? "⌕" : "☆"; color: root.tokens.cyan; font.pixelSize: 38 }
          Text {
            width: parent.width
            text: root.searching ? "No apps found" : root.category === "Favorites" ? "Keep your favorites close" : "Your routine starts here"
            color: root.tokens.text; font.family: root.tokens.font; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
          }
          Text {
            width: parent.width
            text: root.searching ? "Try another name or a shorter search." : root.category === "Favorites" ? "Select ☆ on any app to save it here." : "Apps you launch here will appear in this space."
            color: root.tokens.muted; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
          }
        }
      }
      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.tokens.border }
      RowLayout {
        Layout.fillWidth: true
        spacing: root.compact ? 8 : 14
        Text { text: root.service.pending ? "Opening application…" : root.selected ? root.selected.name : "Ready to explore"; color: root.tokens.muted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
        ShortcutHint { tokens: root.tokens; keys: "↵"; label: "Open"; accent: true }
        ShortcutHint { tokens: root.tokens; visible: !root.compact; keys: "Ctrl F"; label: "Favorite" }
        ShortcutHint { tokens: root.tokens; keys: "Esc"; label: "Close" }
      }
    }
  }

}
