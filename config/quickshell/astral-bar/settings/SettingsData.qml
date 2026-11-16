pragma Singleton
import QtQuick
import "../../common" as Common
import "../../common/Defaults.js" as Defaults

QtObject {
  property Common.SettingsStore local: Common.SettingsStore {
    path: Qt.resolvedUrl("../settings.json")
    scope: "bar"
    defaults: Defaults.bar
  }
  readonly property var value: Object.assign({}, Common.SettingsData.value, local.value)
  readonly property string error: local.error || Common.SettingsData.error
}
