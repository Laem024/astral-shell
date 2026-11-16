import Quickshell
import "common" as Common
ShellRoot {
  Common.PanelControl {
    module: "clipboard"
    entry: Common.Overlays.entry("astral-clipboard") || Quickshell.env("ASTRAL_CLIPBOARD_ENTRY")
    action: Quickshell.env("ASTRAL_CLIPBOARD_ACTION") || "toggle"
    arguments: action === "clear" ? [] : [Quickshell.env("ASTRAL_CLIPBOARD_MODE") || "paste"]
    onFinished: (code, message) => { if (message) console.log(message); Qt.exit(code); }
  }
}
