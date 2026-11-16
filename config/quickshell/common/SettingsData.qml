pragma Singleton
import QtQuick
import "Defaults.js" as Defaults

SettingsStore {
  path: Qt.resolvedUrl("../settings.json")
  scope: "common"
  defaults: Defaults.common
}
