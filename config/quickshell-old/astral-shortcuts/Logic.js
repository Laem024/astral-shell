.pragma library

// Shared descriptions in keybindings.lua use "Category · Label". The panel
// reads the live bindings from Hyprland, so this list only controls the order
// and the glyph of the categories that are already present.
const categoryOrder = ["Apps", "Astral", "Windows", "Workspaces", "Monitors", "Media", "Mouse", "System"];
// Nerd Font glyphs from the Font Awesome range, supplied by the same
// JetBrainsMono Nerd Font used for the key caps.
const categoryGlyphs = {
  "All": "\uf0c9",
  "Apps": "\uf009",
  "Astral": "\uf005",
  "Windows": "\uf2d0",
  "Workspaces": "\uf292",
  "Monitors": "\uf108",
  "Media": "\uf001",
  "Mouse": "\uf245",
  "System": "\uf013",
  "Other": "\uf128"
};

const namedKeys = {
  "Return": "Enter",
  "space": "Space",
  "grave": "`",
  "comma": ",",
  "period": ".",
  "minus": "−",
  "equal": "=",
  "left": "←",
  "right": "→",
  "up": "↑",
  "down": "↓",
  "Page_Up": "PgUp",
  "Page_Down": "PgDn",
  "mouse_down": "Wheel ↓",
  "mouse_up": "Wheel ↑",
  "mouse:272": "Left click",
  "mouse:273": "Right click",
  "XF86AudioRaiseVolume": "Volume +",
  "XF86AudioLowerVolume": "Volume −",
  "XF86AudioMute": "Mute",
  "XF86AudioMicMute": "Mic mute",
  "XF86MonBrightnessUp": "Brightness +",
  "XF86MonBrightnessDown": "Brightness −",
  "XF86AudioNext": "Next",
  "XF86AudioPrev": "Previous",
  "XF86AudioPlay": "Play",
  "XF86AudioPause": "Pause",
  "switch:on:Lid Switch": "Lid switch"
};

const modifierBits = [
  [64, "Super"],
  [4, "Ctrl"],
  [8, "Alt"],
  [1, "Shift"],
  [2, "Caps"],
  [16, "Mod2"],
  [32, "Mod3"],
  [128, "Mod5"]
];

function glyph(category) {
  return categoryGlyphs[category] || categoryGlyphs["Other"];
}

function splitDescription(text) {
  const value = typeof text === "string" ? text.trim() : "";
  const separator = " · ";
  const at = value.indexOf(separator);
  if (at < 0) return { category: "Other", label: value };
  const category = value.slice(0, at).trim();
  const label = value.slice(at + separator.length).trim();
  if (category === "" || label === "") return { category: "Other", label: value };
  return { category: category, label: label };
}

function keyName(key) {
  if (typeof key === "number") return "Keycode " + key;
  if (typeof key !== "string" || key === "") return "Unknown";
  if (Object.prototype.hasOwnProperty.call(namedKeys, key)) return namedKeys[key];
  const lower = key.toLowerCase();
  for (const name of Object.keys(namedKeys)) {
    if (name.toLowerCase() === lower) return namedKeys[name];
  }
  if (/^[a-z]$/.test(key)) return key.toUpperCase();
  return key.replace(/_/g, " ");
}

function modifierNames(modmask) {
  const mask = typeof modmask === "number" ? modmask : 0;
  const names = [];
  for (const [bit, name] of modifierBits) {
    if (mask & bit) names.push(name);
  }
  return names;
}

function formatKeys(bind) {
  if (!bind) return [];
  const keys = modifierNames(bind.modmask);
  const key = bind.key || bind.keycode;
  if (key === undefined || key === null || key === "") {
    if (keys.length > 0) keys.push("Unknown");
    return keys;
  }
  keys.push(keyName(key));
  return keys;
}

function fallbackLabel(bind) {
  const dispatcher = typeof bind.dispatcher === "string" ? bind.dispatcher : "";
  const match = dispatcher.match(/^HL\.Dispatcher\((.+)\)$/);
  if (!match) return "Unlabeled shortcut";
  const name = match[1].replace(/_/g, " ");
  return name === "" ? "Unlabeled shortcut" : name;
}

function entryFor(bind) {
  const parts = splitDescription(bind.description);
  return {
    category: parts.category,
    label: parts.label || fallbackLabel(bind),
    keys: formatKeys(bind)
  };
}

function parseBinds(text) {
  let raw = [];
  try {
    raw = JSON.parse(text);
  } catch (_) {
    return { categories: [], total: 0, error: "Could not read Hyprland shortcuts." };
  }
  if (!Array.isArray(raw)) {
    return { categories: [], total: 0, error: "Could not read Hyprland shortcuts." };
  }

  const buckets = new Map();
  for (const bind of raw) {
    if (!bind || bind.enabled === false) continue;
    if (!bind.key && !bind.keycode) continue;
    const entry = entryFor(bind);
    if (!buckets.has(entry.category)) buckets.set(entry.category, []);
    buckets.get(entry.category).push(entry);
  }

  const known = categoryOrder.filter(name => buckets.has(name));
  const extra = Array.from(buckets.keys())
    .filter(name => !categoryOrder.includes(name) && name !== "Other")
    .sort((a, b) => String(a).localeCompare(String(b)));
  const names = known.concat(extra);
  if (buckets.has("Other")) names.push("Other");

  const categories = names.map(name => ({
    name: name,
    glyph: glyph(name),
    entries: buckets.get(name)
  }));
  const total = categories.reduce((count, category) => count + category.entries.length, 0);
  return { categories: categories, total: total, error: "" };
}

function railFor(categories, total) {
  return [{ name: "All", glyph: glyph("All"), count: total }].concat(
    categories.map(category => ({
      name: category.name,
      glyph: category.glyph,
      count: category.entries.length
    }))
  );
}

function rowsFor(categories, selected) {
  const rows = [];
  for (const category of categories) {
    if (selected !== "All" && category.name !== selected) continue;
    rows.push({
      type: "header",
      name: category.name,
      glyph: category.glyph,
      count: category.entries.length
    });
    for (const entry of category.entries) {
      rows.push({
        type: "entry",
        category: category.name,
        label: entry.label,
        keys: entry.keys
      });
    }
  }
  return rows;
}

// Modifier chips offered by the panel. They match the names produced by
// formatKeys, so filtering never needs to look at the raw modmask again.
const modifierChips = ["Super", "Ctrl", "Alt", "Shift"];

function normalized(value) {
  if (value === undefined || value === null) return "";
  return String(value).toLowerCase();
}

function entryMatches(entry, query, modifiers) {
  if (!entry) return false;
  const terms = normalized(query).trim().split(/\s+/).filter(term => term !== "");
  const haystack = normalized(
    entry.category + " " + entry.label + " " + entry.keys.join(" ")
      + " " + entry.keys.join("+")
  );
  for (const term of terms) {
    if (haystack.indexOf(term) < 0) return false;
  }
  const active = Array.isArray(modifiers) ? modifiers : [];
  for (const modifier of active) {
    if (entry.keys.indexOf(modifier) < 0) return false;
  }
  return true;
}

function filterCategories(categories, query, modifiers) {
  const source = Array.isArray(categories) ? categories : [];
  const result = [];
  for (const category of source) {
    const entries = category.entries.filter(entry => entryMatches(entry, query, modifiers));
    if (entries.length === 0) continue;
    result.push({ name: category.name, glyph: category.glyph, entries: entries });
  }
  return result;
}

function countEntries(categories) {
  let total = 0;
  for (const category of (Array.isArray(categories) ? categories : [])) {
    total += category.entries.length;
  }
  return total;
}

// The "All" view uses two independent columns so cards keep their natural
// height instead of stretching to the tallest card in a grid row.
function splitColumns(categories) {
  const left = [];
  const right = [];
  const heights = [0, 0];
  for (const category of (Array.isArray(categories) ? categories : [])) {
    const target = heights[0] <= heights[1] ? 0 : 1;
    (target === 0 ? left : right).push(category);
    // A category header is roughly one and a half rows tall.
    heights[target] += category.entries.length + 1.5;
  }
  return { left: left, right: right };
}

function clampIndex(index, length) {
  if (length <= 0) return 0;
  if (index < 0) return 0;
  if (index >= length) return length - 1;
  return index;
}
