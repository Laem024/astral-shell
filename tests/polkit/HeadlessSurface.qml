import QtQuick
Item {
  required property var service
  required property var tokens
  required property var monitor
  signal cancelRequested()
  signal submitRequested(string value)
  property alias password: content.password
  function focusInput() { content.focusInput(); }
  width: 800; height: 650
  PolkitContent {
    id: content
    anchors.fill: parent
    service: parent.service; tokens: parent.tokens
    onCancelRequested: parent.cancelRequested()
    onSubmitRequested: value => parent.submitRequested(value)
  }
}
