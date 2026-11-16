import Quickshell
import "common" as Common
ShellRoot {
  Common.PanelControl {
    module: "overview"
    entry: Common.Overlays.entry("astral-overview") || Quickshell.env("ASTRAL_OVERVIEW_ENTRY")
    action: Quickshell.env("ASTRAL_OVERVIEW_ACTION") || "toggle"
    arguments: action === "clear" ? [] : action === "alt-tab" ? [Quickshell.env("ASTRAL_OVERVIEW_ARGUMENT") || "next", ""] : [Quickshell.env("ASTRAL_OVERVIEW_ARGUMENT") || "", ""]
    onFinished: (code, message) => { if (message) console.log(message); Qt.exit(code); }
  }
}
