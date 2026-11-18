pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import "../../common" as Design
import "../components" as Components
import "../data" as Data

Rectangle {
  id: root
  required property Design.Theme tokens
  property bool compact: false
  readonly property string profileName: Data.UserData.displayName
  readonly property string initials: profileName.split(/\s+/).filter(word => word.length).slice(0, 2).map(word => word[0]).join("").toUpperCase()
  signal editRequested(string mode)
  implicitHeight: compact ? 168 : 204
  radius: tokens.cardRadius
  color: tokens.background
  border.color: tokens.border
  gradient: Gradient {
    orientation: Gradient.Horizontal
    GradientStop { position: 0; color: Qt.tint(root.tokens.background, Qt.alpha(root.tokens.cyan, 0.18)) }
    GradientStop { position: 0.55; color: Qt.tint(root.tokens.background, Qt.alpha(root.tokens.lavender, 0.13)) }
    GradientStop { position: 1; color: root.tokens.background }
  }
  // The default banner is native geometry; only photographs need a mask.
  Shape {
    anchors { top: parent.top; right: parent.right; margins: 12 }
    width: Math.min(300, root.width * 0.45); height: 110
    opacity: Data.BannerData.file ? 0 : 1
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: "transparent"
      strokeColor: Qt.alpha(root.tokens.lavender, 0.28)
      strokeWidth: 1
      PathSvg { path: "M10 85 C45 0 185 0 220 85 M35 85 C65 20 165 20 195 85 M60 85 C85 40 145 40 170 85" }
    }
    Rectangle { x: 111; y: 53; width: 7; height: 7; radius: 3.5; color: root.tokens.gold }
  }
  Components.RoundedClip {
    anchors.fill: parent
    radius: root.radius
    visible: Data.BannerData.file !== ""
    Components.CropImage {
      anchors.fill: parent
      source: Data.BannerData.source
      zoom: Data.BannerData.zoom
      focusX: Data.BannerData.focusX
      focusY: Data.BannerData.focusY
    }
    Rectangle {
      anchors.fill: parent
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.alpha(root.tokens.background, 0.12) }
        GradientStop { position: 0.4; color: Qt.alpha(root.tokens.background, 0.35) }
        GradientStop { position: 1; color: Qt.alpha(root.tokens.background, 0.97) }
      }
    }
  }
  RowLayout {
    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
    Text {
      Layout.fillWidth: true
      text: "ASTRAL / CONTROL CENTER"
      color: root.tokens.text
      font { family: root.tokens.font; pixelSize: 11; weight: Font.DemiBold; letterSpacing: 0.6 }
      elide: Text.ElideRight
    }
    PanelButton {
      tokens: root.tokens
      text: "Edit banner"
      symbol: "+"
      implicitHeight: 30
      onClicked: root.editRequested("banner")
    }
  }
  RowLayout {
    objectName: "panelAccount"
    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 20 }
    spacing: 16
    PanelButton {
      id: portrait
      tokens: root.tokens
      text: "Change account photo"
      Layout.minimumWidth: root.compact ? 88 : 112
      Layout.preferredWidth: root.compact ? 88 : 112
      Layout.preferredHeight: root.compact ? 88 : 112
      padding: 5
      leftPadding: 5
      rightPadding: 5
      topPadding: 5
      bottomPadding: 5
      onClicked: root.editRequested("avatar")
      background: Rectangle {
        radius: portrait.width * 0.3
        color: root.tokens.surface
        border.width: portrait.visualFocus ? 2 : 1
        border.color: portrait.hovered || portrait.visualFocus ? root.tokens.cyan : Qt.alpha(root.tokens.cyan, 0.4)
      }
      contentItem: Item {
        Rectangle {
          anchors.fill: parent
          radius: portrait.width * 0.25
          color: Qt.tint(root.tokens.raised, Qt.alpha(root.tokens.lavender, 0.12))
        }
        Components.RoundedClip {
          anchors.fill: parent
          radius: portrait.width * 0.25
          visible: avatar.status === Image.Ready
          Image {
            id: avatar
            anchors.fill: parent
            source: Data.UserData.avatar
            cache: false
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
          }
        }
        Text {
          anchors.centerIn: parent
          visible: avatar.status !== Image.Ready
          text: root.initials
          color: root.tokens.cyan
          font { family: root.tokens.font; pixelSize: root.compact ? 30 : 38; weight: Font.DemiBold }
        }
        Rectangle {
          anchors { right: parent.right; bottom: parent.bottom; rightMargin: -7; bottomMargin: -7 }
          width: 24; height: 24; radius: 9
          color: root.tokens.cyan
          border.width: 3; border.color: root.tokens.surface
          CategoryGlyph { anchors.centerIn: parent; kind: "edit"; ink: root.tokens.background; scale: 0.48; width: 24; height: 24 }
        }
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: 4
      Text {
        Layout.fillWidth: true
        text: "YOUR SPACE, IN SYNC"
        color: root.tokens.cyan
        elide: Text.ElideRight
        font { family: root.tokens.font; pixelSize: 10; weight: Font.DemiBold; letterSpacing: 0.6 }
      }
      Text {
        Layout.fillWidth: true
        text: root.profileName
        textFormat: Text.PlainText
        color: root.tokens.text
        elide: Text.ElideRight
        font { family: root.tokens.font; pixelSize: root.compact ? 21 : 28; weight: Font.DemiBold }
      }
      Text {
        Layout.fillWidth: true
        text: "@" + Data.UserData.username
        textFormat: Text.PlainText
        color: root.tokens.muted
        elide: Text.ElideRight
        font { family: root.tokens.font; pixelSize: 12; weight: Font.Medium }
      }
    }
  }
}
