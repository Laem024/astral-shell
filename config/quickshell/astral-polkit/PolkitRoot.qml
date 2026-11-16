import Quickshell
import "../common" as Common
ShellRoot {
  Common.Theme { id: theme; settings: Common.SettingsData }
  PolkitService { id: service }
  PolkitDialog { service: service; tokens: theme }
}
