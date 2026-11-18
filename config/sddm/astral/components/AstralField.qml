import QtQuick

FocusScope {
  id: root
  required property var tokens

  property alias text: input.text
  property alias echoMode: input.echoMode
  property string placeholderText: ""
  property bool error: false
  property bool busy: false

  signal accepted()
  signal escapePressed()

  implicitWidth: 280
  implicitHeight: root.tokens.fieldHeight

  function forceInputFocus() {
    input.forceActiveFocus()
  }

  function clear() {
    input.text = ""
  }

  Rectangle {
    anchors.fill: parent
    radius: root.tokens.rowRadius
    color: root.error ? Qt.alpha(root.tokens.alert, 0.08) : root.tokens.sunken
    border.width: input.activeFocus || root.error ? 2 : 1
    border.color: root.error ? Qt.alpha(root.tokens.alert, 0.8)
      : input.activeFocus ? root.tokens.cyan
      : root.tokens.border

    Behavior on border.color {
      ColorAnimation { duration: root.tokens.hoverDuration }
    }
    Behavior on color {
      ColorAnimation { duration: root.tokens.hoverDuration }
    }
  }

  TextInput {
    id: input
    anchors {
      left: parent.left
      right: parent.right
      leftMargin: 16
      rightMargin: 16
      verticalCenter: parent.verticalCenter
    }
    height: implicitHeight
    color: root.tokens.text
    selectionColor: Qt.alpha(root.tokens.cyan, 0.25)
    selectedTextColor: root.tokens.text
    font {
      family: root.tokens.mono
      pixelSize: root.tokens.labelSize
      letterSpacing: input.text.length > 0 ? 3 : 0
    }
    echoMode: TextInput.Password
    passwordCharacter: "●"
    passwordMaskDelay: 0
    selectByMouse: false
    persistentSelection: false
    enabled: !root.busy
    inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

    onAccepted: root.accepted()

    Keys.onPressed: event => {
      if (event.matches(StandardKey.Copy) || event.matches(StandardKey.Cut)
          || event.matches(StandardKey.Paste) || event.matches(StandardKey.SelectAll)
          || (event.modifiers & (Qt.ControlModifier | Qt.MetaModifier))
          || event.key === Qt.Key_Insert || event.key === Qt.Key_Menu)
        event.accepted = true;
      if (event.key === Qt.Key_Escape) {
        root.escapePressed();
        event.accepted = true;
      }
    }
  }

  Text {
    anchors {
      left: parent.left
      right: parent.right
      leftMargin: 16
      rightMargin: 16
      verticalCenter: parent.verticalCenter
    }
    text: root.placeholderText
    visible: input.text.length === 0
    opacity: input.activeFocus ? 0.6 : 0.9
    color: root.tokens.muted
    elide: Text.ElideRight
    font {
      family: root.tokens.font
      pixelSize: root.tokens.bodySize
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    cursorShape: Qt.IBeamCursor
    onPressed: input.forceActiveFocus()
  }
}
