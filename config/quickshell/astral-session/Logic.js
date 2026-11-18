.pragma library

const holdDuration = 900;
const actions = [
  { id: "lock", label: "Lock", detail: "Secure this session", glyph: "󰌾", shortcut: "L", key: "L", accent: "cyan", hold: false },
  { id: "suspend", label: "Suspend", detail: "Resume where you left off", glyph: "󰒲", shortcut: "S", key: "S", accent: "cyan", hold: false },
  { id: "logout", label: "Log out", detail: "Close this Hyprland session", glyph: "󰍃", shortcut: "O", key: "O", accent: "lavender", hold: true },
  { id: "reboot", label: "Restart", detail: "Reboot the computer", glyph: "󰜉", shortcut: "R", key: "R", accent: "gold", hold: true },
  { id: "poweroff", label: "Shut down", detail: "Power off safely", glyph: "󰐥", shortcut: "P", key: "P", accent: "alert", hold: true }
];

function byId(id) {
  for (const action of actions) if (action.id === id) return action;
  return null;
}

function valid(id) { return byId(id) !== null; }

function requiresHold(id) {
  const action = byId(id);
  return !!action && action.hold;
}

function shortcutAction(text) {
  if (typeof text !== "string" || text.length !== 1) return "";
  const key = text.toUpperCase();
  for (const action of actions) if (action.key === key) return action.id;
  return "";
}
