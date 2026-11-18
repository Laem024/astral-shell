import Quickshell
import "common" as Common
ShellRoot {
  Common.PanelControl {
    module: "settings"
    entry: Common.Overlays.entry("astral-settings") || Quickshell.env("ASTRAL_SETTINGS_ENTRY")
    action: Quickshell.env("ASTRAL_SETTINGS_ACTION") || "open"
    onFinished: (code, message) => { if (message) console.log(message); Qt.exit(code); }
  }
}
