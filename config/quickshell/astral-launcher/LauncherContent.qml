pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
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
  function cycleCategory(step) {
    const index = root.sections.findIndex(section => section.key === root.category);
    root.choose(root.sections[(index + step + root.sections.length) % root.sections.length].key);
  }
  Keys.onEscapePressed: closeRequested()
  Keys.onPressed: event => {
    if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
      root.cycleCategory(event.key === Qt.Key_Left ? -1 : 1);
      event.accepted = true;
    } else if (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier)) {
      if (selected) service.pin(selected);
      event.accepted = true;
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12
    RowLayout {
      Layout.fillWidth: true
      TextField {
        id: search
        objectName: "launcherSearch"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        implicitHeight: 44
        leftPadding: 16; rightPadding: 16
        topPadding: 10; bottomPadding: 10
        placeholderText: "Search applications"
        Accessible.name: "Search applications"
        selectByMouse: true
        color: root.tokens.text
        placeholderTextColor: root.tokens.muted
        font { family: root.tokens.font; pixelSize: 14 }
        background: Rectangle {
          radius: root.tokens.rowRadius
          color: root.tokens.sunken
          border.width: search.activeFocus ? 2 : 1
          border.color: search.activeFocus ? root.tokens.cyan : root.tokens.border
        }
        onTextChanged: { grid.currentIndex = 0; grid.positionViewAtBeginning(); }
        Keys.onDownPressed: if (root.results.length) { grid.forceActiveFocus(); grid.currentIndex = Math.max(0, grid.currentIndex); }
        Keys.onUpPressed: if (root.results.length) { grid.forceActiveFocus(); grid.currentIndex = root.results.length - 1; }
        Keys.onLeftPressed: root.cycleCategory(-1)
        Keys.onRightPressed: root.cycleCategory(1)
        onAccepted: root.activate()
      }
      Button {
        id: closeButton
        text: "×"
        Accessible.name: "Close launcher"
        onClicked: root.closeRequested()
        background: Rectangle {
          color: "transparent"
          border.color: closeButton.visualFocus ? root.tokens.cyan : "transparent"
          radius: root.tokens.rowRadius
        }
        contentItem: Text {
          text: closeButton.text
          color: closeButton.hovered ? root.tokens.cyan : root.tokens.muted
          font.pixelSize: 22
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 4
      Repeater {
        model: root.sections
        Button {
          id: tab
          required property var modelData
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          implicitHeight: 32
          Accessible.name: modelData.label
          Accessible.role: Accessible.RadioButton
          Accessible.checkable: true
          Accessible.checked: root.category === modelData.key
          onClicked: root.choose(modelData.key)
          contentItem: Text {
            text: tab.modelData.label
            color: root.category === tab.modelData.key ? root.tokens.cyan : root.tokens.muted
            font { family: root.tokens.font; pixelSize: 12 }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
          }
          background: Rectangle {
            color: "transparent"
            border.color: tab.visualFocus ? root.tokens.cyan : "transparent"
            Rectangle {
              anchors.bottom: parent.bottom
              width: parent.width
              height: 2
              color: root.category === tab.modelData.key ? root.tokens.cyan : root.tokens.hairline
            }
          }
        }
      }
    }
    Text {
      Layout.fillWidth: true
      visible: text !== ""
      text: root.service.error || root.service.warning
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      color: root.service.error ? root.tokens.alert : root.tokens.gold
      font { family: root.tokens.font; pixelSize: 11 }
    }
    ListView {
      id: grid
      objectName: "launcherResults"
      property real translation: 0
      transform: Translate { y: grid.translation }
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 0
      model: root.results
      clip: true
      spacing: 4
      boundsBehavior: Flickable.StopAtBounds
      keyNavigationEnabled: true
      ScrollBar.vertical: ScrollBar {}
      Keys.onReturnPressed: root.activate()
      Keys.onEnterPressed: root.activate()
      Keys.onUpPressed: event => {
        if (currentIndex <= 0) search.forceActiveFocus();
        else event.accepted = false;
      }
      Keys.onLeftPressed: root.cycleCategory(-1)
      Keys.onRightPressed: root.cycleCategory(1)
      delegate: Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool selected: grid.currentIndex === index
        readonly property bool pinned: root.service.state.favorites.includes(Logic.identity(modelData))
        width: grid.width
        height: 64
        Rectangle {
          anchors.fill: parent
          radius: root.tokens.rowRadius
          color: row.selected ? Qt.alpha(root.tokens.cyan, 0.09) : "transparent"
          border.color: row.selected && grid.activeFocus ? root.tokens.cyan : "transparent"
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { grid.currentIndex = row.index; grid.forceActiveFocus(); root.service.launch(row.modelData); }
        }
        RowLayout {
          anchors.fill: parent
          anchors.margins: 10
          spacing: 12
          Image {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            source: Quickshell.iconPath(row.modelData.icon || "application-x-executable", "application-x-executable")
            fillMode: Image.PreserveAspectFit
            asynchronous: true
          }
          ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 3
            Text {
              Layout.fillWidth: true
              text: row.modelData.name
              textFormat: Text.PlainText
              elide: Text.ElideRight
              color: row.selected ? root.tokens.cyan : root.tokens.text
              font { family: root.tokens.font; pixelSize: 14; weight: Font.Medium }
            }
            Text {
              Layout.fillWidth: true
              text: row.modelData.comment || row.modelData.genericName || ""
              textFormat: Text.PlainText
              visible: text !== ""
              elide: Text.ElideRight
              color: root.tokens.muted
              font { family: root.tokens.font; pixelSize: 11 }
            }
          }
          Button {
            id: pin
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Accessible.name: (row.pinned ? "Unpin " : "Pin ") + row.modelData.name
            onClicked: root.service.pin(row.modelData)
            contentItem: Item {
              Shape {
                anchors.centerIn: parent
                width: 20; height: 20
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                  strokeColor: row.pinned ? root.tokens.gold : pin.hovered ? root.tokens.cyan : root.tokens.muted
                  strokeWidth: 1.5
                  joinStyle: ShapePath.RoundJoin
                  fillColor: row.pinned ? root.tokens.gold : "transparent"
                  PathSvg { path: "M10 1.5 L12.6 6.8 L18.5 7.6 L14.2 11.8 L15.2 17.7 L10 14.9 L4.8 17.7 L5.8 11.8 L1.5 7.6 L7.4 6.8 Z" }
                }
              }
            }
            background: Rectangle {
              color: "transparent"
              radius: root.tokens.rowRadius
              border.color: pin.visualFocus ? root.tokens.cyan : "transparent"
            }
          }
        }
      }
      Text {
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 32)
        visible: root.results.length === 0
        text: root.searching ? "No apps found. Try another name."
          : root.category === "Favorites" ? "Select ☆ to add favorites." : "No applications yet."
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: root.tokens.muted
        font { family: root.tokens.font; pixelSize: 13 }
      }
    }
    RowLayout {
      Layout.fillWidth: true
      Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: root.service.pending ? "Opening application…" : root.results.length + " applications"
        color: root.tokens.muted
        elide: Text.ElideRight
        font { family: root.tokens.font; pixelSize: 11 }
      }
      ShortcutHint { tokens: root.tokens; visible: root.width >= 480; keys: "← →"; label: "Categories" }
      ShortcutHint { tokens: root.tokens; keys: "↵"; label: "Open" }
      ShortcutHint { tokens: root.tokens; visible: root.width >= 480; keys: "Ctrl F"; label: "Favorite" }
      ShortcutHint { tokens: root.tokens; keys: "Esc"; label: "Close" }
    }
  }
}
