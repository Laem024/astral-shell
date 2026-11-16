import Quickshell
import "../common" as Common
ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  AppLauncher { settings: Common.SettingsData; tokens: theme }
}
