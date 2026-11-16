pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../design" as Design
import "../data" as Data

FocusScope {
  id: root
  objectName: "windowMenu"
  required property Design.Theme tokens
  property var window: Data.WindowData
  signal dismissed()
  implicitHeight: layout.implicitHeight
  focus: true
  Keys.onEscapePressed: root.dismissed()
  Component.onCompleted: {
    // The menu may open long after the window changed mode, so ask Hyprland
    // for a fresh snapshot before the switch paints its state.
    root.window.refreshFloating();
    modeToggle.forceActiveFocus();
  }

  component SectionLabel: Text {
    Layout.fillWidth: true
    textFormat: Text.PlainText
    color: root.tokens.muted
    font.family: root.tokens.mono
    font.pixelSize: 8
    font.letterSpacing: 0.8
  }

  ColumnLayout {
    id: layout
    anchors.fill: parent
    spacing: 10

    SectionLabel { text: "FOCUS" }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2
      Text {
        Layout.fillWidth: true
        text: root.window.title
        textFormat: Text.PlainText
        color: root.tokens.text
        elide: Text.ElideRight
        maximumLineCount: 1
        font { family: root.tokens.font; pixelSize: 15; weight: Font.Medium }
      }
      Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: root.window.activeWindow ? (root.window.activeWindow.appId || "") : ""
        textFormat: Text.PlainText
        color: root.tokens.muted
        elide: Text.ElideRight
        maximumLineCount: 1
        font { family: root.tokens.mono; pixelSize: 10 }
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.topMargin: 2
      spacing: 8
      SectionLabel { text: "WINDOW MODE" }
      Text {
        text: "SUPER + T"
        textFormat: Text.PlainText
        color: root.tokens.muted
        font { family: root.tokens.mono; pixelSize: 8; letterSpacing: 0.6 }
      }
    }

    // The whole row is one toggle; there is no separate destination button
    // that can look inert when it already represents the current mode.
    PanelButton {
      id: modeToggle
      objectName: "windowModeToggle"
      Layout.fillWidth: true
      implicitHeight: 58
      leftPadding: 12
      rightPadding: 12
      tokens: root.tokens
      text: "Floating window"
      Accessible.checkable: true
      Accessible.checked: root.window.floating
      contentItem: RowLayout {
        spacing: 10
        Item {
          implicitWidth: 24
          implicitHeight: 18
          Rectangle {
            anchors.fill: parent
            radius: 3
            color: "transparent"
            border.width: 1
            border.color: root.window.floating ? root.tokens.cyan : root.tokens.muted
            opacity: root.window.floating ? 1 : 0.55
          }
          // Tiled: two panes filling the frame.
          Rectangle {
            visible: !root.window.floating
            x: 2; y: 2
            width: (parent.width - 5) / 2
            height: parent.height - 4
            radius: 1
            color: root.tokens.muted
            opacity: 0.55
          }
          Rectangle {
            visible: !root.window.floating
            x: 2 + (parent.width - 5) / 2 + 1; y: 2
            width: (parent.width - 5) / 2
            height: parent.height - 4
            radius: 1
            color: root.tokens.muted
            opacity: 0.55
          }
          // Floating: one inset pane.
          Rectangle {
            visible: root.window.floating
            anchors.centerIn: parent
            width: parent.width * 0.55
            height: parent.height * 0.6
            radius: 1
            color: root.tokens.cyan
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: 1
          Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: modeToggle.text
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: modeToggle.hovered || modeToggle.activeFocus ? root.tokens.cyan : root.tokens.text
            font { family: root.tokens.font; pixelSize: 12; weight: Font.Medium }
          }
          Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.window.floating ? "On · detached from layout" : "Off · docked in layout"
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.tokens.muted
            font { family: root.tokens.mono; pixelSize: 9 }
          }
        }
        Rectangle {
          implicitWidth: 46
          implicitHeight: 24
          radius: 12
          color: root.window.floating
            ? root.tokens.cyan : Qt.alpha(root.tokens.muted, 0.22)
          border.color: modeToggle.activeFocus ? root.tokens.text
            : root.window.floating ? "transparent" : root.tokens.border
          Behavior on color { ColorAnimation { duration: root.tokens.hoverDuration } }
          Rectangle {
            y: 3
            x: root.window.floating ? 25 : 3
            width: 18; height: 18
            radius: 9
            color: root.window.floating ? root.tokens.background : root.tokens.muted
            Behavior on x { NumberAnimation { duration: root.tokens.hoverDuration } }
          }
        }
      }
      background: Rectangle {
        radius: 8
        color: root.window.floating ? Qt.alpha(root.tokens.cyan, 0.07)
          : modeToggle.hovered ? Qt.alpha(root.tokens.cyan, 0.04)
          : root.tokens.background
        border.color: modeToggle.activeFocus ? root.tokens.cyan : root.tokens.border
        Rectangle {
          visible: root.window.floating
          width: 2
          height: parent.height - 20
          x: 0
          y: 10
          radius: 1
          color: root.tokens.cyan
        }
      }
      onClicked: { root.window.toggleFloating(); root.dismissed(); }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 1
      color: root.tokens.border
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      PanelButton {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: 0
        tokens: root.tokens
        text: "Close window"
        onClicked: { root.window.close(); root.dismissed(); }
      }
      PanelButton {
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.minimumWidth: 0
        tokens: root.tokens
        text: "Force close"
        destructive: true
        onClicked: { root.window.forceClose(); root.dismissed(); }
      }
    }
  }
}
