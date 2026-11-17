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
    { key: "Home", label: "Discover", detail: "Your everyday essentials" },
    { key: "Favorites", label: "Favorites", detail: "Always within reach" },
    { key: "Frequent", label: "Frequent", detail: "Your most used apps" },
    { key: "All", label: "All apps", detail: "Explore your collection" }
  ]
  function countFor(key: string): string {
    return key === "Home" ? "" : String(Logic.select(service.entries, service.state, key, "").length).padStart(2, "0");
  }
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
      Layout.preferredWidth: 220
      Layout.fillHeight: true
      color: root.tokens.sunken
      ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 24
        anchors.bottomMargin: 16
        spacing: 0
        RowLayout {
          Layout.fillWidth: true
          spacing: 12
          Rectangle {
            Layout.preferredWidth: 40; Layout.preferredHeight: 40
            radius: root.tokens.rowRadius + 2
            color: root.tokens.cyan
            Text {
              anchors.centerIn: parent
              text: "A"
              color: root.tokens.background
              font.family: root.tokens.mono
              font.pixelSize: 18
              font.weight: Font.Bold
            }
          }
          ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 2
            Text {
              Layout.fillWidth: true
              text: "Astral"
              color: root.tokens.text
              font.family: root.tokens.font
              font.pixelSize: 16
              font.weight: Font.DemiBold
              elide: Text.ElideRight
            }
            Text {
              Layout.fillWidth: true
              text: "App library"
              color: root.tokens.muted
              font.family: root.tokens.font
              font.pixelSize: 11
              elide: Text.ElideRight
            }
          }
        }
        Item { Layout.preferredHeight: 28 }
        Text {
          text: "BROWSE"
          color: root.tokens.muted
          font.family: root.tokens.mono
          font.pixelSize: 10
          font.letterSpacing: 1.4
          Layout.bottomMargin: 4
        }
        Repeater {
          model: root.sections
          delegate: Button {
            id: section
            required property var modelData
            readonly property bool selected: root.category === modelData.key
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            leftPadding: 14; rightPadding: 12
            topPadding: 0; bottomPadding: 0
            focusPolicy: Qt.StrongFocus
            onClicked: root.choose(modelData.key)
            contentItem: RowLayout {
              spacing: 8
              Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: section.modelData.label
                color: section.selected ? root.tokens.text : root.tokens.muted
                font.family: root.tokens.font
                font.pixelSize: 13
                font.weight: section.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
              }
              Text {
                visible: text !== ""
                text: root.countFor(section.modelData.key)
                color: section.selected ? root.tokens.cyan : root.tokens.muted
                font.family: root.tokens.mono
                font.pixelSize: 11
              }
            }
            background: Rectangle {
              radius: root.tokens.rowRadius
              color: section.selected ? root.tokens.raised
                : section.hovered ? Qt.alpha(root.tokens.muted, 0.07) : "transparent"
              border.width: 1
              border.color: section.activeFocus ? root.tokens.cyan
                : section.selected ? root.tokens.border : "transparent"
              Rectangle {
                visible: section.selected
                x: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 3; height: 16; radius: 1.5
                color: root.tokens.cyan
              }
              Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
            }
            scale: down ? 0.98 : 1
            Behavior on scale { NumberAnimation { duration: root.tokens.hoverDuration; easing.type: Easing.OutCubic } }
          }
        }
        Item { Layout.fillHeight: true }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.tokens.hairline }
        Text {
          Layout.fillWidth: true
          Layout.topMargin: 12
          text: root.service.entries.filter(e => !e.noDisplay).length + " apps, one place."
          color: root.tokens.muted
          font.family: root.tokens.font
          font.pixelSize: 11
          wrapMode: Text.Wrap
        }
      }
    }
    Rectangle { visible: !root.compact; Layout.fillHeight: true; Layout.preferredWidth: 1; color: root.tokens.hairline }
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.margins: root.compact ? 16 : 24
      spacing: root.compact ? 12 : 16
      RowLayout {
        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: 4
          Text {
            text: root.searching ? "Search results" : root.category === "Home" ? "Your applications" : root.sections.find(s => s.key === root.category).label
            color: root.tokens.text; font.family: root.tokens.font; font.pixelSize: root.compact ? 20 : 26; font.weight: Font.DemiBold
            Layout.fillWidth: true; elide: Text.ElideRight
          }
          Text {
            visible: !root.compact
            Layout.fillWidth: true
            text: root.searching ? "Find an app and press Enter to open it." : root.category === "Home" ? "Favorites and familiar places, a little closer." : root.sections.find(s => s.key === root.category).detail
            color: root.tokens.muted; font.family: root.tokens.font; font.pixelSize: 12
            elide: Text.ElideRight
          }
        }
        Button {
          id: closeButton
          Layout.preferredWidth: 32; Layout.preferredHeight: 32
          Layout.alignment: Qt.AlignTop
          Accessible.name: "Close launcher"
          onClicked: root.closeRequested()
          contentItem: Text { text: "×"; color: closeButton.hovered ? root.tokens.text : root.tokens.muted; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
          background: Rectangle {
            radius: height / 2
            color: closeButton.hovered ? root.tokens.raised : "transparent"
            border.width: 1
            border.color: closeButton.activeFocus ? root.tokens.cyan : closeButton.hovered ? root.tokens.border : "transparent"
          }
        }
      }
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: root.compact ? 44 : 48
        radius: root.tokens.rowRadius
        color: root.tokens.sunken
        border.width: search.activeFocus ? 2 : 1
        border.color: search.activeFocus ? Qt.alpha(root.tokens.cyan, 0.7) : root.tokens.border
        Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 14; anchors.rightMargin: 8
          spacing: 10
          Item {
            Layout.preferredWidth: 18; Layout.preferredHeight: 18
            Rectangle {
              x: 2; y: 2; width: 11; height: 11; radius: 6
              color: "transparent"; border.width: 1.6
              border.color: search.activeFocus ? root.tokens.cyan : root.tokens.muted
            }
            Rectangle {
              x: 12; y: 12; width: 6; height: 1.6; rotation: 45
              transformOrigin: Item.Left; radius: 1
              color: search.activeFocus ? root.tokens.cyan : root.tokens.muted
            }
          }
          TextField {
            id: search
            Layout.fillWidth: true; Layout.fillHeight: true
            Layout.minimumWidth: 0
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
            contentItem: Text { text: "×"; color: clearButton.hovered ? root.tokens.text : root.tokens.muted; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle {
              radius: height / 2
              color: clearButton.hovered ? root.tokens.raised : "transparent"
              border.width: 1
              border.color: clearButton.activeFocus ? root.tokens.cyan : "transparent"
            }
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
            readonly property bool current: root.category === compactSection.modelData.key
            Layout.fillWidth: true; Layout.preferredHeight: 30
            focusPolicy: Qt.StrongFocus
            onClicked: root.choose(modelData.key)
            contentItem: Text {
              text: compactSection.modelData.label
              color: compactSection.current ? root.tokens.cyan : root.tokens.muted
              font.family: root.tokens.font
              font.pixelSize: 11
              font.weight: compactSection.current ? Font.DemiBold : Font.Normal
              horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }
            background: Rectangle {
              radius: height / 2
              color: compactSection.current ? root.tokens.raised : "transparent"
              border.width: 1
              border.color: compactSection.activeFocus ? root.tokens.cyan
                : compactSection.current ? Qt.alpha(root.tokens.cyan, 0.35) : "transparent"
            }
          }
        }
      }
      Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.service.error || root.service.warning
        color: root.service.error ? root.tokens.alert : root.tokens.gold
        wrapMode: Text.Wrap; font.family: root.tokens.font; font.pixelSize: 11
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text {
          text: root.searching ? "SEARCH RESULTS" : root.category === "Home" ? (root.homeEntries.length ? "PICK UP WHERE YOU LEFT OFF" : "EXPLORE YOUR APPS") : root.category.toUpperCase()
          color: root.tokens.muted; font.family: root.tokens.mono; font.pixelSize: 10; font.letterSpacing: 1.2
          Layout.fillWidth: true; elide: Text.ElideRight
        }
        Text { text: root.results.length.toString().padStart(2, "0"); color: root.tokens.cyan; font.family: root.tokens.mono; font.pixelSize: 11 }
      }
      GridView {
        id: grid
        property real translation: 0
        transform: Translate { y: grid.translation }
        Layout.fillWidth: true; Layout.fillHeight: true
        Layout.minimumHeight: 0
        clip: true
        model: root.results
        cellWidth: width / Math.max(1, Math.floor(width / (root.compact ? 116 : 144)))
        cellHeight: root.compact ? 112 : 148
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
            anchors.fill: parent; anchors.margins: 6
            radius: root.tokens.cardRadius
            color: tile.selected ? Qt.alpha(root.tokens.cyan, 0.1) : hover.hovered ? root.tokens.raised : "transparent"
            border.width: 1
            border.color: tile.selected ? Qt.alpha(root.tokens.cyan, grid.activeFocus ? 0.85 : 0.45) : "transparent"
            Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
            Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: { grid.currentIndex = tile.index; grid.forceActiveFocus(); root.service.launch(tile.modelData); }
            }
          }
          HoverHandler { id: hover }
          Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: root.compact ? 12 : 16
            width: parent.width - 24
            spacing: root.compact ? 8 : 10
            Rectangle {
              id: iconWell
              anchors.horizontalCenter: parent.horizontalCenter
              width: root.compact ? 52 : 64; height: width
              radius: width / 2
              color: Qt.alpha(root.tokens.cyan, tile.selected || hover.hovered ? 0.1 : 0.05)
              border.width: 1
              border.color: Qt.alpha(root.tokens.cyan, tile.selected ? 0.32 : 0.12)
              Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
              Image {
                id: icon
                anchors.centerIn: parent
                width: root.compact ? 30 : 38; height: width
                source: Quickshell.iconPath(tile.modelData.icon || "application-x-executable", "application-x-executable")
                fillMode: Image.PreserveAspectFit
                asynchronous: true
              }
              Text { anchors.centerIn: parent; visible: icon.status !== Image.Ready; text: "◇"; color: root.tokens.cyan; font.pixelSize: 26 }
            }
            Text {
              width: parent.width
              text: tile.modelData.name
              color: tile.selected ? root.tokens.cyan : root.tokens.text
              font.family: root.tokens.font
              font.pixelSize: root.compact ? 12 : 13
              font.weight: Font.Medium
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
            }
          }
          Button {
            id: pin
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
            width: 28; height: 28
            opacity: tile.pinned || hover.hovered || tile.selected || activeFocus ? 1 : 0
            Accessible.name: (tile.pinned ? "Unpin " : "Pin ") + tile.modelData.name
            ToolTip.visible: hovered
            ToolTip.text: tile.pinned ? "Remove from favorites" : "Add to favorites"
            onClicked: root.service.pin(tile.modelData)
            contentItem: Text { text: tile.pinned ? "★" : "☆"; color: tile.pinned ? root.tokens.gold : root.tokens.muted; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle {
              radius: height / 2
              color: pin.hovered ? root.tokens.raised : "transparent"
              border.width: 1
              border.color: pin.activeFocus ? root.tokens.cyan : "transparent"
            }
            Behavior on opacity { NumberAnimation { duration: root.tokens.hoverDuration } }
          }
        }
        Column {
          anchors.centerIn: parent
          width: Math.max(0, parent.width - 48)
          spacing: 12
          visible: root.results.length === 0
          Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.searching ? "⌕" : "☆"; color: root.tokens.cyan; font.pixelSize: 36 }
          Text {
            width: parent.width
            text: root.searching ? "No apps found" : root.category === "Favorites" ? "Keep your favorites close" : "Your routine starts here"
            color: root.tokens.text; font.family: root.tokens.font; font.pixelSize: 17; font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
          }
          Text {
            width: parent.width
            text: root.searching ? "Try another name or a shorter search." : root.category === "Favorites" ? "Select ☆ on any app to save it here." : "Apps you launch here will appear in this space."
            color: root.tokens.muted; font.family: root.tokens.font; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
          }
        }
      }
      Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.tokens.hairline }
      RowLayout {
        Layout.fillWidth: true
        spacing: root.compact ? 8 : 14
        Text {
          text: root.service.pending ? "Opening application…" : root.selected ? root.selected.name : "Ready to explore"
          color: root.tokens.muted; font.family: root.tokens.font; font.pixelSize: 11
          Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight
        }
        ShortcutHint { tokens: root.tokens; keys: "↵"; label: "Open"; accent: true }
        ShortcutHint { tokens: root.tokens; visible: !root.compact; keys: "Ctrl F"; label: "Favorite" }
        ShortcutHint { tokens: root.tokens; keys: "Esc"; label: "Close" }
      }
    }
  }

}
