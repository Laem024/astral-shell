.pragma library

function internal(name) { return /^(eDP|LVDS|DSI)-/.test(name); }
function resolve(name, monitors, backlights, connectors) {
  if (internal(name)) {
    if (monitors.filter(m => internal(m.name)).length === 1 && backlights.length === 1)
      return {backend: "backlight", device: backlights[0]};
    return {backend: "", device: "", reason: "Ambiguous backlight mapping."};
  }
  const matches = connectors.filter(path => new RegExp("/card[0-9]+-" + name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + "$").test(path));
  return matches.length === 1 ? {backend: "ddc", connector: matches[0], device: ""}
    : {backend: "", device: "", reason: "No unique DRM connector for this display."};
}
function percentage(current, maximum) {
  if (!/^\d+$/.test(String(current)) || !/^\d+$/.test(String(maximum))) throw new Error("Invalid brightness response.");
  const a = Number(current), b = Number(maximum);
  if (!Number.isFinite(a) || !Number.isFinite(b) || b <= 0 || a < 0 || a > b) throw new Error("Invalid brightness response.");
  return Math.round(a * 100 / b);
}
