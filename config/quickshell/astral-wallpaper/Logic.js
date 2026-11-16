.pragma library

function defaults(folder) {
  return {version: 1, folder: folder, layout: "Mirror", fade: 500,
    rotation: false, minutes: 30, random: true,
    selections: {light: {common: "", monitors: {}}, dark: {common: "", monitors: {}}}};
}
function parse(text, folder) {
  const d = defaults(folder), s = JSON.parse(text);
  if (!s || s.version !== 1) throw new Error("Unsupported wallpaper state.");
  if (typeof s.folder !== "string" || s.folder[0] !== "/" || s.folder.includes("\0")) throw new Error("Invalid library folder.");
  if (!["Mirror", "Span", "Per monitor"].includes(s.layout)) throw new Error("Invalid wallpaper preference.");
  if (!Number.isFinite(s.fade) || s.fade < 0 || s.fade > 5000 || !Number.isFinite(s.minutes) || s.minutes < 1 || s.minutes > 10080 || typeof s.rotation !== "boolean" || typeof s.random !== "boolean") throw new Error("Invalid timing preference.");
  for (const theme of ["light", "dark"]) {
    const v = s.selections && s.selections[theme];
    if (!v || typeof v.common !== "string" || !v.monitors || typeof v.monitors !== "object" || Array.isArray(v.monitors) || Object.values(v.monitors).some(p => typeof p !== "string")) throw new Error("Invalid assignments.");
    d.selections[theme] = {common: v.common, monitors: Object.assign({}, v.monitors)};
    if (v.layouts !== undefined) {
      if (!v.layouts || typeof v.layouts !== "object" || Array.isArray(v.layouts)) throw new Error("Invalid layout assignments.");
      for (const layout of Object.keys(v.layouts)) {
        const item = v.layouts[layout];
        if (!["Mirror", "Span", "Per monitor"].includes(layout) || !item || typeof item.common !== "string" || !item.monitors || typeof item.monitors !== "object" || Array.isArray(item.monitors) || Object.values(item.monitors).some(p => typeof p !== "string")) throw new Error("Invalid layout assignments.");
      }
      d.selections[theme].layouts = JSON.parse(JSON.stringify(v.layouts));
    }
  }
  for (const key of ["folder", "layout", "fade", "rotation", "minutes", "random"]) d[key] = s[key];
  return d;
}
// The module theme is the single source of truth: its mode selects the collection.
function theme(mode) { return mode === "light" ? "light" : "dark"; }
function kind(path) {
  const ext = path.split(".").pop().toLowerCase();
  return ["mp4", "webm", "mkv"].includes(ext) ? "video" : ext === "gif" ? "gif" : ["png", "jpg", "jpeg", "webp", "bmp"].includes(ext) ? "image" : "";
}
function classify(relative) {
  const parts = relative.split("/");
  // Only the root collection folders have special meaning.
  return parts.length > 1 && ["light", "dark"].includes(parts[0]) ? parts[0] : "shared";
}
function collection(entries, selected, query) {
  const q = (query || "").toLocaleLowerCase();
  return entries.filter(e => (e.theme === "shared" || e.theme === selected) && e.name.toLocaleLowerCase().includes(q));
}
function choose(entries, previous, random, sample) {
  if (entries.length < 2) return entries.length ? entries[0].path : previous;
  const index = entries.findIndex(e => e.path === previous);
  if (!random) return entries[(index + 1) % entries.length].path;
  const alternatives = entries.filter(e => e.path !== previous);
  return alternatives[Math.min(alternatives.length - 1, Math.floor((sample === undefined ? Math.random() : sample) * alternatives.length))].path;
}
// Seed each layout from the legacy fields before any explicit assignment changes them.
function ensureLayouts(selection) {
  if (!selection.layouts) selection.layouts = {};
  for (const layout of ["Mirror", "Span", "Per monitor"])
    if (!selection.layouts[layout]) selection.layouts[layout] = {common: selection.common, monitors: Object.assign({}, selection.monitors)};
}
function assignments(state, selected, entries, names) {
  const selection = state.selections[selected];
  const saved = selection.layouts && selection.layouts[state.layout] || selection, result = {};
  const valid = path => entries.some(e => e.path === path) ? path : (entries[0] ? entries[0].path : "");
  for (const name of names) result[name] = valid(state.layout === "Per monitor" ? saved.monitors[name] : saved.common);
  return result;
}
function bounds(screens) {
  if (!screens.length) return {x: 0, y: 0, width: 1, height: 1};
  const x = Math.min.apply(null, screens.map(s => s.x)), y = Math.min.apply(null, screens.map(s => s.y));
  return {x: x, y: y, width: Math.max.apply(null, screens.map(s => s.x + s.width)) - x,
    height: Math.max.apply(null, screens.map(s => s.y + s.height)) - y};
}
function fileUrl(path) { return path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""; }
