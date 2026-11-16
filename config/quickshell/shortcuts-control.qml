import Quickshell
import "common" as Common
ShellRoot {
  Common.PanelControl {
    module: "shortcuts"
    entry: Common.Overlays.entry("astral-shortcuts") || Quickshell.env("ASTRAL_SHORTCUTS_ENTRY")
    action: Quickshell.env("ASTRAL_SHORTCUTS_ACTION") || "toggle"
    arguments: action === "clear" ? [] : [""]
    onFinished: (code, message) => { if (message) console.log(message); Qt.exit(code); }
  }
}
