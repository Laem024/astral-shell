pragma ComponentBehavior: Bound
import "../common" as Common
import QtQuick
import QtQuick.Layouts

Rectangle {
  id: root
  required property var tokens
  required property var category
  property color accent: root.tokens.cyan
  property int columns: 1
  property bool compact: false

  readonly property int padding: root.compact ? 12 : 16
  readonly property int entryCount: root.category.entries.length
  implicitWidth: 300
  implicitHeight: layout.implicitHeight + root.padding * 2
  radius: root.tokens.cardRadius
  color: root.tokens.sunken
  border.width: 1
  border.color: root.tokens.hairline

  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: root.padding
    spacing: root.compact ? 8 : 12

    RowLayout {
      Layout.fillWidth: true
      spacing: root.compact ? 8 : 12

      Rectangle {
        Layout.preferredWidth: root.compact ? 28 : 32
        Layout.preferredHeight: Layout.preferredWidth
        radius: root.tokens.rowRadius
        color: Qt.alpha(root.accent, 0.12)
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.35)
        Text {
          anchors.centerIn: parent
          text: root.category.glyph
          color: root.accent
          font {
            family: root.tokens.mono
            pixelSize: root.compact ? 14 : 16
            weight: Font.DemiBold
          }
        }
      }

      Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: root.category.name
        elide: Text.ElideRight
        color: root.tokens.text
        font {
          family: root.tokens.font
          pixelSize: root.compact ? 13 : 14
          weight: Font.DemiBold
        }
      }

      Rectangle {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: countText.implicitWidth + 12
        implicitHeight: 20
        radius: height / 2
        color: Qt.alpha(root.accent, 0.1)
        Text {
          id: countText
          anchors.centerIn: parent
          text: root.entryCount
          color: root.accent
          font {
            family: root.tokens.mono
            pixelSize: 10
            weight: Font.DemiBold
          }
        }
      }
    }

    GridLayout {
      Layout.fillWidth: true
      columns: Math.max(1, root.columns)
      columnSpacing: root.compact ? 8 : 16
      rowSpacing: 4

      Repeater {
        model: root.category.entries
        delegate: ShortcutRow {
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredWidth: 0
          Layout.minimumWidth: 0
          tokens: root.tokens
          entry: modelData
          compact: root.compact
        }
      }
    }
  }
}
