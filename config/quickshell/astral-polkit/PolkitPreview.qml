import QtQuick
import Quickshell
import "../common" as Common
ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  QtObject {
    id: demo
    property bool blocked: false
    property var flow: QtObject {
      property bool isResponseRequired: true
      property bool failed: false
      property string supplementaryMessage: ""
      property bool supplementaryIsError: false
      property bool responseVisible: false
      property string message: "Authentication is required to change system settings."
      property string inputPrompt: "Password:"
      property string actionId: "org.astral.preview"
      property var identities: [{id: 1000, displayName: "Preview user", string: "unix-user:preview", isGroup: false}]
      property var selectedIdentity: identities[0]
    }
    signal responseCleared()
    signal requestStarted()
    signal requestFinished()
    function select(identity) { flow.selectedIdentity = identity; }
  }
  FloatingWindow {
    id: window
    title: "Astral Polkit preview"
    implicitWidth: 800; implicitHeight: 650
    color: theme.background
    PolkitContent {
      anchors.fill: parent
      service: demo; tokens: theme
      onSubmitRequested: { demo.flow.isResponseRequired = false; reset.restart(); }
      onCancelRequested: window.visible = false
    }
  }
  Timer { id: reset; interval: 1200; onTriggered: demo.flow.isResponseRequired = true }
}
