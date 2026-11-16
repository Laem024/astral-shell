.pragma library

const palette = {
  background: "color", surface: "color", text: "color", muted: "color",
  cyan: "color", lavender: "color", gold: "color", alert: "color"
};
const shape = {
  mode: "string", scale: "number", animations: "boolean",
  historySize: "count", enterAction: "string",
  pasteShortcut: { mods: "modifier", key: "key" },
  maxImageBytes: "count",
  colors: { light: palette, dark: palette }
};
const choices = { mode: ["light", "dark"], enterAction: ["paste", "copy"] };

function validate(value, expected, path, key) {
  if (expected && typeof expected === "object") {
    if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(path);
    for (const name of Object.keys(expected)) {
      if (!Object.prototype.hasOwnProperty.call(value, name)) throw new Error(path + "." + name);
      validate(value[name], expected[name], path + "." + name, name);
    }
    if (path === "settings.colors" || path.startsWith("settings.colors.")) {
      for (const name of Object.keys(value)) if (!(name in expected)) throw new Error(path + "." + name);
    }
    return;
  }
  if (expected === "count") {
    if (!Number.isInteger(value)) throw new Error(path);
    if (key === "historySize" && (value < 1 || value > 500)) throw new Error(path);
    if (key === "maxImageBytes" && (value < 1 || value > 1073741824)) throw new Error(path);
    return;
  }
  if (expected === "modifier") {
    if (typeof value !== "string" || !/^[A-Za-z0-9_ +,-]*$/.test(value)) throw new Error(path);
    return;
  }
  if (expected === "key") {
    if (typeof value !== "string" || !/^[A-Za-z0-9_]+$/.test(value)) throw new Error(path);
    return;
  }
  if (expected === "color") {
    if (typeof value !== "string" || !/^#[0-9a-fA-F]{3,8}$/.test(value)) throw new Error(path);
    return;
  }
  if (typeof value !== expected || (expected === "number" && !Number.isFinite(value))) throw new Error(path);
  if (choices[key] && !choices[key].includes(value)) throw new Error(path);
  if (key === "scale" && (value < 0.5 || value > 3)) throw new Error(path);
}

function parse(text) {
  const value = JSON.parse(text);
  validate(value, shape, "settings", "settings");
  return value;
}
