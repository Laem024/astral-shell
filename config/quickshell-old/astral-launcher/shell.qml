import Quickshell
import "settings" as Settings
import "design" as Design

ShellRoot {
  Design.Theme { id: theme; settings: Settings.SettingsData }
  AppLauncher { settings: Settings.SettingsData; tokens: theme }
}
