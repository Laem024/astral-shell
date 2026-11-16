.pragma library

function validItem(item) {
  return item && typeof item === "object"
    && typeof item.id === "string" && /^[0-9a-f]{64}$/.test(item.id)
    && (item.kind === "text" || item.kind === "image")
    && Number.isFinite(item.time)
    && (item.kind !== "text" || typeof item.text === "string")
    && (item.kind !== "image" || (typeof item.file === "string" && item.file !== ""));
}

function parseState(text) {
  const value = JSON.parse(text);
  if (!value || !Array.isArray(value.items)) throw new Error("Invalid clipboard state");
  return {
    dir: typeof value.dir === "string" ? value.dir : "",
    items: value.items.filter(validItem).map(item => Object.assign({}, item))
  };
}

function preview(item) {
  if (!item) return "";
  if (item.kind === "image") return "Image · " + mimeLabel(item.mime);
  const text = String(item.text || "").replace(/[\r\n\t]+/g, " ").replace(/\s+/g, " ").trim();
  return text.length > 160 ? text.slice(0, 157) + "…" : text;
}

function mimeLabel(mime) {
  if (!mime) return "file";
  const type = String(mime).split(";")[0];
  const parts = type.split("/");
  return (parts[1] || type).replace(/^x-/, "").toUpperCase();
}

function formatBytes(bytes) {
  const value = Number(bytes);
  if (!Number.isFinite(value) || value < 0) return "";
  if (value < 1024) return value + " B";
  if (value < 1024 * 1024) return (value / 1024).toFixed(value < 10240 ? 1 : 0) + " KB";
  if (value < 1024 * 1024 * 1024) return (value / (1024 * 1024)).toFixed(value < 10485760 ? 1 : 0) + " MB";
  return (value / (1024 * 1024 * 1024)).toFixed(1) + " GB";
}

function relativeTime(time, now) {
  const seconds = Math.max(0, Math.floor((Number(now) - Number(time)) / 1000));
  if (!Number.isFinite(seconds)) return "";
  if (seconds < 10) return "just now";
  if (seconds < 60) return seconds + "s ago";
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return minutes + " min ago";
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return hours + " h ago";
  const days = Math.floor(hours / 24);
  return days + " d ago";
}

function luaShortcut(mods, key) {
  return "hl.dsp.send_shortcut({ mods = " + JSON.stringify(String(mods || ""))
    + ", key = " + JSON.stringify(String(key || "")) + " })";
}

function shortcutLabel(mods, key) {
  const parts = String(mods || "").split(/[\s,+]+/).filter(Boolean);
  parts.push(String(key || ""));
  return parts.join("+");
}
