pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Logic.js" as Logic

FocusScope {
  id: root
  required property var service
  required property var tokens
  required property var settings
  property string mode: "paste"
  property bool active: false
  property double now: Date.now()
  readonly property bool compact: width < 780
  readonly property var items: service.items
  readonly property var selected: list.currentIndex >= 0 && list.currentIndex < items.length ? items[list.currentIndex] : null
  readonly property int limit: settings.value.historySize || 50
  signal closeRequested()
  signal acceptRequested(var item)
  signal removeRequested(string id)

  onModeChanged: reset()
  onItemsChanged: {
    if (list.currentIndex >= items.length) list.currentIndex = items.length - 1;
    if (items.length === 0) list.currentIndex = -1;
  }
  Timer {
    interval: 30000
    repeat: true
    running: root.active
    onTriggered: root.now = Date.now()
  }
  function reset() {
    list.currentIndex = root.items.length ? 0 : -1;
    list.positionViewAtBeginning();
    if (root.active) list.forceActiveFocus();
  }
  function accept() { if (root.selected) root.acceptRequested(root.selected); }
  function removeSelected() {
    if (root.mode === "delete" && root.selected) root.removeRequested(root.selected.id);
  }
  Keys.onEscapePressed: root.closeRequested()

  RowLayout {
    anchors.fill: parent
    spacing: 0
    ColumnLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.margins: root.compact ? 16 : 24
      spacing: 14
      RowLayout {
        Layout.fillWidth: true
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 3
          Text {
            text: "CLIPBOARD"
            color: root.tokens.muted
            font.family: root.tokens.font
            font.pixelSize: 9
            font.letterSpacing: 1.8
          }
          Text {
            Layout.fillWidth: true
            text: root.mode === "delete" ? "Delete an entry" : "Clipboard history"
            color: root.tokens.text
            font.family: root.tokens.font
            font.pixelSize: root.compact ? 22 : 28
            font.weight: Font.DemiBold
            elide: Text.ElideRight
          }
          Text {
            Layout.fillWidth: true
            text: root.mode === "delete"
              ? "Choose an entry and press Enter to remove it."
              : "Your recent copies, ready to paste."
            color: root.tokens.muted
            font.family: root.tokens.font
            font.pixelSize: 12
          }
        }
        Rectangle {
          Layout.preferredWidth: modeLabel.implicitWidth + 20
          Layout.preferredHeight: 26
          radius: 13
          color: Qt.alpha(root.mode === "delete" ? root.tokens.alert : root.tokens.cyan, 0.12)
          border.color: Qt.alpha(root.mode === "delete" ? root.tokens.alert : root.tokens.cyan, 0.35)
          Text {
            id: modeLabel
            anchors.centerIn: parent
            text: root.mode === "delete" ? "DELETE MODE" : "PASTE MODE"
            color: root.mode === "delete" ? root.tokens.alert : root.tokens.cyan
            font.family: root.tokens.mono
            font.pixelSize: 9
            font.letterSpacing: 1.2
          }
        }
        Button {
          id: closeButton
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
          Accessible.name: "Close clipboard history"
          onClicked: root.closeRequested()
          contentItem: Text {
            text: "×"
            color: root.tokens.muted
            font.pixelSize: 23
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          background: Rectangle {
            radius: 16
            color: closeButton.hovered ? Qt.alpha(root.tokens.muted, 0.12) : "transparent"
            border.color: closeButton.activeFocus ? root.tokens.cyan : root.tokens.border
          }
        }
      }
      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: root.tokens.border
      }
      ListView {
        id: list
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 4
        model: root.items
        boundsBehavior: Flickable.StopAtBounds
        keyNavigationEnabled: true
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Keys.onReturnPressed: root.accept()
        Keys.onEnterPressed: root.accept()
        Keys.onDeletePressed: root.removeSelected()
        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index
          readonly property bool selected: list.currentIndex === index
          readonly property bool image: modelData.kind === "image"
          width: list.width
          height: 64
          radius: 12
          color: row.selected ? Qt.alpha(root.tokens.cyan, 0.11)
            : hover.hovered ? Qt.alpha(root.tokens.muted, 0.06) : "transparent"
          border.color: row.selected ? Qt.alpha(root.tokens.cyan, 0.5) : "transparent"
          Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
          Behavior on border.color { ColorAnimation { duration: root.tokens.hoverDuration } }
          HoverHandler { id: hover }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              list.currentIndex = row.index;
              list.forceActiveFocus();
              if (root.mode !== "delete") root.acceptRequested(row.modelData);
            }
          }
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            spacing: 12
            Rectangle {
              Layout.preferredWidth: 44
              Layout.preferredHeight: 44
              radius: 10
              color: Qt.alpha(root.tokens.cyan, 0.07)
              Image {
                id: thumbnail
                anchors.fill: parent
                anchors.margins: 2
                visible: row.image && status === Image.Ready
                source: row.image ? root.service.source(row.modelData) : ""
                sourceSize: Qt.size(88, 88)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
              }
              Text {
                anchors.centerIn: parent
                visible: !row.image
                text: "≡"
                color: row.selected ? root.tokens.cyan : root.tokens.muted
                font.pixelSize: 21
              }
              Text {
                anchors.centerIn: parent
                visible: row.image && thumbnail.status !== Image.Ready
                text: "▣"
                color: root.tokens.muted
                font.pixelSize: 18
              }
            }
            ColumnLayout {
              Layout.fillWidth: true
              Layout.minimumWidth: 0
              spacing: 2
              Text {
                Layout.fillWidth: true
                text: row.image ? "Image" : Logic.preview(row.modelData)
                color: root.tokens.text
                font.family: root.tokens.font
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
              }
              Text {
                Layout.fillWidth: true
                text: row.image
                  ? Logic.mimeLabel(row.modelData.mime) + " · " + Logic.formatBytes(row.modelData.bytes) + " · " + Logic.relativeTime(row.modelData.time, root.now)
                  : Logic.relativeTime(row.modelData.time, root.now)
                color: root.tokens.muted
                font.family: root.tokens.mono
                font.pixelSize: 9
                elide: Text.ElideRight
              }
            }
            Button {
              id: deleteButton
              visible: root.mode === "delete" && (row.selected || hover.hovered)
              Layout.preferredWidth: 30
              Layout.preferredHeight: 30
              Accessible.name: "Remove clipboard entry"
              onClicked: root.removeRequested(row.modelData.id)
              contentItem: Text {
                text: "⌫"
                color: deleteButton.hovered ? root.tokens.alert : root.tokens.muted
                font.pixelSize: 17
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
              background: Rectangle {
                radius: 8
                color: deleteButton.hovered ? Qt.alpha(root.tokens.alert, 0.1) : "transparent"
                border.color: deleteButton.activeFocus ? root.tokens.cyan : "transparent"
              }
            }
          }
        }
        Column {
          anchors.centerIn: parent
          width: Math.max(0, parent.width - 48)
          spacing: 10
          visible: root.items.length === 0
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "▤"
            color: root.tokens.cyan
            font.pixelSize: 36
          }
          Text {
            width: parent.width
            text: "Nothing copied yet"
            color: root.tokens.text
            font.family: root.tokens.font
            font.pixelSize: 17
            horizontalAlignment: Text.AlignHCenter
          }
          Text {
            width: parent.width
            text: "Copy text or an image and it will appear here."
            color: root.tokens.muted
            font.family: root.tokens.font
            font.pixelSize: 12
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
      Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.service.error || root.service.warning
        color: root.service.error ? root.tokens.alert : root.tokens.gold
        wrapMode: Text.Wrap
        font.family: root.tokens.font
        font.pixelSize: 11
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: root.compact ? 8 : 14
        Text {
          text: root.items.length + " / " + root.limit
          color: root.tokens.cyan
          font.family: root.tokens.mono
          font.pixelSize: 11
        }
        Text {
          Layout.fillWidth: true
          text: root.service.watching ? "History updates automatically." : "Clipboard capture is paused."
          color: root.tokens.muted
          font.family: root.tokens.font
          font.pixelSize: 10
          elide: Text.ElideRight
        }
        ShortcutHint { tokens: root.tokens; keys: "↑ ↓"; label: "Navigate" }
        ShortcutHint {
          tokens: root.tokens
          keys: "↵"
          label: root.mode === "delete" ? "Delete" : "Paste"
          accent: true
        }
        ShortcutHint { tokens: root.tokens; keys: "Esc"; label: "Close" }
      }
    }
    Rectangle {
      visible: !root.compact
      Layout.fillHeight: true
      Layout.preferredWidth: 1
      color: root.tokens.border
    }
    ColumnLayout {
      visible: !root.compact
      Layout.preferredWidth: 300
      Layout.fillHeight: true
      Layout.margins: 24
      spacing: 10
      Text {
        text: "PREVIEW"
        color: root.tokens.muted
        font.family: root.tokens.font
        font.pixelSize: 9
        font.letterSpacing: 1.6
      }
      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 16
        color: root.tokens.background
        border.color: root.tokens.border
        clip: true
        Item {
          anchors.fill: parent
          anchors.margins: 14
          Text {
            anchors.centerIn: parent
            visible: !root.selected
            text: "Select an entry"
            color: root.tokens.muted
            font.family: root.tokens.font
            font.pixelSize: 12
          }
          Flickable {
            anchors.fill: parent
            visible: root.selected && root.selected.kind === "text"
            clip: true
            contentWidth: width
            contentHeight: previewText.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            Text {
              id: previewText
              width: parent.width
              text: root.selected && root.selected.kind === "text" ? root.selected.text : ""
              color: root.tokens.text
              font.family: root.tokens.mono
              font.pixelSize: 11
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
            }
          }
          Image {
            anchors.fill: parent
            visible: root.selected && root.selected.kind === "image"
            source: root.selected ? root.service.source(root.selected) : ""
            sourceSize: Qt.size(560, 560)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
          }
        }
      }
      Text {
        Layout.fillWidth: true
        visible: root.selected !== null
        text: root.selected && root.selected.kind === "image"
          ? Logic.mimeLabel(root.selected.mime) + " · " + Logic.formatBytes(root.selected.bytes)
          : (root.selected ? root.selected.text.length + " characters" : "")
        color: root.tokens.muted
        font.family: root.tokens.mono
        font.pixelSize: 9
        elide: Text.ElideRight
      }
    }
  }
}
