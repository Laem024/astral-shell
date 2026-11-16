.pragma library

const fallbackCount = 10;

function count(value) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 1 || number > 100) return fallbackCount;
  return Math.floor(number);
}

function activeId(value) {
  const number = Number(value);
  if (!Number.isFinite(number) || number < 1) return 1;
  return Math.floor(number);
}

function blockStart(id, size) {
  const slots = count(size);
  return Math.floor((activeId(id) - 1) / slots) * slots;
}

function blockIds(id, size) {
  const start = blockStart(id, size);
  const slots = count(size);
  const values = [];
  for (let index = 0; index < slots; index++) values.push(start + index + 1);
  return values;
}

function focusHistory(window) {
  const value = window && window.lastIpcObject
    ? Number(window.lastIpcObject.focusHistoryID) : NaN;
  return Number.isFinite(value) ? value : Number.MAX_SAFE_INTEGER;
}

function sortWindows(windows) {
  return Array.from(windows || []).slice().sort((left, right) =>
    focusHistory(left) - focusHistory(right));
}

function direction(value) {
  if (value === "previous" || value === -1) return -1;
  if (value === 0 || value === "active") return 0;
  return 1;
}

function wrap(index, length) {
  if (length <= 0) return -1;
  return ((index % length) + length) % length;
}

function dropTarget(position, rects, sourceWorkspaceId) {
  if (!position) return -1;
  for (const rect of rects || []) {
    if (!rect || rect.width <= 0 || rect.height <= 0) continue;
    if (position.x < rect.x || position.y < rect.y) continue;
    if (position.x > rect.x + rect.width || position.y > rect.y + rect.height) continue;
    if (rect.id !== sourceWorkspaceId) return rect.id;
  }
  return -1;
}

function activeWorkspaceIndex(ids, activeId, delta) {
  if (!Array.isArray(ids) || ids.length === 0) return -1;
  const index = ids.indexOf(activeId);
  if (index >= 0) return wrap(index + delta, ids.length);
  return delta < 0 ? ids.length - 1 : 0;
}

function luaString(value) {
  return '"' + String(value).replace(/[\\"\x00-\x1f\x7f]/g, character => {
    if (character === '\\' || character === '"') return '\\' + character;
    return '\\' + String(character.charCodeAt(0)).padStart(3, '0');
  }) + '"';
}

function moveCommand(address, workspaceId, usingLua) {
  const target = Math.trunc(Number(workspaceId));
  const normalized = windowAddress(address);
  if (!normalized || !Number.isFinite(target) || target < 1) return "";
  return usingLua
    ? 'hl.dsp.window.move({ window = ' + luaString("address:" + normalized)
      + ', workspace = ' + target + ', follow = false })'
    : "movetoworkspacesilent " + target + ",address:" + normalized;
}

function moveWorkspaceCommand(workspaceId, monitorName, usingLua) {
  const target = Math.trunc(Number(workspaceId));
  const monitor = String(monitorName || "").trim();
  if (!Number.isFinite(target) || target < 1 || !monitor) return "";
  return usingLua
    ? 'hl.dsp.workspace.move({ workspace = ' + target + ', monitor = '
      + luaString(monitor) + ' })'
    : "moveworkspacetomonitor " + target + " " + monitor;
}

function windowAddress(window) {
  const raw = typeof window === "string" ? window
    : (window && (window.address || (window.lastIpcObject && window.lastIpcObject.address)) || "");
  const match = String(raw).match(/^(?:0x)?([0-9a-fA-F]+)$/);
  return match ? "0x" + match[1].toLowerCase() : "";
}

function windowAppId(window) {
  return String(window && (window.appId || window.class
    || (window.lastIpcObject && window.lastIpcObject.class) || "") || "");
}

function windowTitle(window) {
  return String(window && (window.title || (window.lastIpcObject && window.lastIpcObject.title)
    || "Untitled window") || "Untitled window");
}
