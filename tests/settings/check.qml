import QtQuick
import Quickshell
import "../../config/quickshell/common" as Common
import "../../config/quickshell/astral-bar/settings" as Bar

ShellRoot {
  Component.onCompleted: {
    if (!Common.SettingsData.value.modules || !Bar.SettingsData.value.position) Qt.exit(1);
    console.log("SETTINGS_PASS");
    Qt.quit();
  }
}
