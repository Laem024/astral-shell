.pragma library

function emptyState() { return { version: 1, favorites: [], usage: {} }; }
function parseState(text) {
  const s = JSON.parse(text);
  if (!s || s.version !== 1 || !Array.isArray(s.favorites) || !s.usage || typeof s.usage !== "object" || Array.isArray(s.usage)
      || s.favorites.some(id => typeof id !== "string")) throw new Error("Invalid launcher state");
  Object.keys(s.usage).forEach(id => {
    const u = s.usage[id];
    if (!u || !Number.isSafeInteger(u.count) || u.count < 0 || !Number.isFinite(u.last) || u.last < 0) throw new Error("Invalid launcher usage");
  });
  return s;
}
function fold(text) { return text.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim(); }
function identity(entry) { return entry.id.endsWith(".desktop") ? entry.id : entry.id + ".desktop"; }
function alphabetical(a, b) { return fold(a.name).localeCompare(fold(b.name)) || identity(a).localeCompare(identity(b)); }
function rank(name, query) { const n = fold(name); return n === query ? 0 : n.startsWith(query) ? 1 : n.includes(query) ? 2 : 3; }
function favorites(entries, state) { return entries.filter(e => state.favorites.includes(identity(e))).sort(alphabetical); }
function frequent(entries, state) {
  return entries.filter(e => state.usage[identity(e)] && state.usage[identity(e)].count > 0).sort((a, b) => {
    const x = state.usage[identity(a)], y = state.usage[identity(b)];
    return y.count - x.count || y.last - x.last || alphabetical(a, b);
  });
}
function select(entries, state, category, query) {
  const all = entries.filter(e => !e.noDisplay);
  const q = fold(query);
  if (q) return all.filter(e => rank(e.name, q) < 3).sort((a, b) => rank(a.name, q) - rank(b.name, q) || alphabetical(a, b));
  if (category === "Favorites") return favorites(all, state);
  if (category === "Frequent") return frequent(all, state);
  if (category === "All") return all.slice().sort(alphabetical);
  const pinned = favorites(all, state);
  return pinned.concat(frequent(all, state).filter(e => !state.favorites.includes(identity(e))).slice(0, 12));
}
function toggle(state, id) {
  const next = JSON.parse(JSON.stringify(state));
  next.favorites = next.favorites.includes(id) ? next.favorites.filter(x => x !== id) : next.favorites.concat([id]);
  return next;
}
function record(state, id, now) {
  const next = JSON.parse(JSON.stringify(state));
  const old = next.usage[id] || { count: 0, last: 0 };
  next.usage[id] = { count: old.count + 1, last: now };
  return next;
}
function launchCommand(entry, terminal) {
  if (!entry.runInTerminal) return ["gtk-launch", identity(entry)];
  if (!terminal.length || !entry.command.length) throw new Error("No terminal or application command configured.");
  return terminal.concat(["-e"]).concat(Array.from(entry.command));
}
