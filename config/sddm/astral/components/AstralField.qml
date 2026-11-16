import QtQuick

FocusScope {
  id: root
  required property var tokens

  property alias text: input.text
  property alias echoMode: input.echoMode
  property string placeholderText: ""
  property bool error: false
  property bool busy: false
  property int trailingInset: 0

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
    radius: root.tokens.fieldRadius
    color: root.error ? Qt.alpha(root.tokens.alert, 0.08) : root.tokens.glassSoft
    border.width: input.activeFocus || root.error ? 2 : 1
    border.color: root.error ? Qt.alpha(root.tokens.alert, 0.7)
      : input.activeFocus ? Qt.alpha(root.tokens.cyan, 0.6)
      : root.tokens.glassEdge

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
      leftMargin: 18
      rightMargin: 18 + root.trailingInset
      verticalCenter: parent.verticalCenter
    }
    height: implicitHeight
    color: root.tokens.text
    selectionColor: Qt.alpha(root.tokens.cyan, 0.25)
    selectedTextColor: root.tokens.text
    font {
      family: root.tokens.mono
      pixelSize: 13
      letterSpacing: input.text.length > 0 ? 4 : 0
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
      leftMargin: 18
      rightMargin: 18 + root.trailingInset
      verticalCenter: parent.verticalCenter
    }
    text: root.placeholderText
    visible: input.text.length === 0
    opacity: input.activeFocus ? 0.5 : 0.9
    color: root.tokens.muted
    elide: Text.ElideRight
    font {
      family: root.tokens.font
      pixelSize: 12
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
    cursorShape: Qt.IBeamCursor
    onPressed: input.forceActiveFocus()
  }
}
