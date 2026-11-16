.pragma library

function request(value) {
  if (!value || !["shot", "record"].includes(value.kind) || !["monitor", "region", "window"].includes(value.mode)
      || value.kind === "record" && value.mode === "window" || !["none", "system", "microphone", "both"].includes(value.audio)
      || typeof value.monitor !== "string" || /[\u0000\r\n]/.test(value.monitor)) throw new Error("Invalid capture request.");
  return value;
}
function region(text) {
  const m = /^(-?\d+),(-?\d+) (\d+)x(\d+)$/.exec(text.trim());
  if (!m || Number(m[3]) <= 0 || Number(m[4]) <= 0) throw new Error("Invalid region returned by selector.");
  return {x: Number(m[1]), y: Number(m[2]), width: Number(m[3]), height: Number(m[4]), text: text.trim()};
}
function outputForRegion(region, monitors) {
  const matches = monitors.filter(m => {
    const rotated = Number(m.transform) % 2 === 1;
    const width = (rotated ? m.height : m.width) / m.scale;
    const height = (rotated ? m.width : m.height) / m.scale;
    return region.x >= m.x && region.y >= m.y && region.x + region.width <= m.x + width && region.y + region.height <= m.y + height;
  });
  if (matches.length !== 1) throw new Error("Keep the recording region inside a single display.");
  return matches[0].name;
}
function bluetoothCard(name) {
  if (name.startsWith("bluez_input.")) return "bluez_card." + name.slice(12).replace(/\.[^.]+$/, "").replace(/:/g, "_");
  if (name.startsWith("bluez_output.")) return "bluez_card." + name.slice(13).replace(/\.[^.]+$/, "");
  return "";
}
