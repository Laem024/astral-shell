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

  readonly property int padding: root.compact ? 13 : 17
  readonly property int entryCount: root.category.entries.length
  implicitWidth: 300
  implicitHeight: layout.implicitHeight + root.padding * 2
  radius: root.tokens.cardRadius
  color: Qt.alpha(root.tokens.muted, 0.035)
  border.width: 1
  border.color: Qt.alpha(root.tokens.muted, 0.1)

  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: root.padding
    spacing: root.compact ? 6 : 8

    RowLayout {
      Layout.fillWidth: true
      spacing: root.compact ? 8 : 10

      Rectangle {
        Layout.preferredWidth: root.compact ? 30 : 34
        Layout.preferredHeight: Layout.preferredWidth
        radius: root.compact ? 8 : 10
        color: Qt.alpha(root.accent, 0.12)
        border.width: 1
        border.color: Qt.alpha(root.accent, 0.3)
        Text {
          anchors.centerIn: parent
          text: root.category.glyph
          color: root.accent
          font {
            family: root.tokens.mono
            pixelSize: root.compact ? 15 : 17
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
          pixelSize: root.compact ? 12 : 13
          weight: Font.DemiBold
          letterSpacing: 0.2
        }
      }

      Text {
        text: root.entryCount
        color: root.accent
        font {
          family: root.tokens.mono
          pixelSize: root.compact ? 9 : 10
          weight: Font.DemiBold
        }
      }
    }

    GridLayout {
      Layout.fillWidth: true
      Layout.topMargin: root.compact ? 2 : 4
      columns: Math.max(1, root.columns)
      columnSpacing: root.compact ? 10 : 14
      rowSpacing: 0

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
