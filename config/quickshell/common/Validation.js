.pragma library

const palette = {
  background: "color", surface: "color", text: "color", muted: "color",
  cyan: "color", lavender: "color", gold: "color", alert: "color"
};
const shape = {
  position: "string", frame: "string", mode: "string", scale: "number", margin: "number", animations: "boolean",
  colors: { light: palette, dark: palette },
  clockFormat: "string", workspaceDisplay: "string",
  modules: {
    logo: "boolean", workspaces: "boolean", window: "boolean", clock: "boolean",
    music: "boolean", network: "boolean", audio: "boolean", battery: "boolean",
    notifications: "boolean", tray: "boolean", capture: "boolean"
  },
  applications: { fileManager: "strings", terminal: "strings", videoPlayer: "strings" },
  weather: { temperatureUnit: "string", windUnit: "string" },
  logo: { glyph: "string", image: "string" }
};
const choices = {
  frame: ["off", "folds", "full"],
  position: ["top", "bottom", "left", "right"], mode: ["light", "dark"],
  clockFormat: ["12h", "24h"], workspaceDisplay: ["icons", "numbers"],
  temperatureUnit: ["celsius", "fahrenheit"], windUnit: ["kmh", "mph", "ms", "kn"]
};
const optionalCommon = {
  workspaceCount: "number",
  clipboard: {historySize: "number", enterAction: "string", maxImageBytes: "number", pasteShortcut: {mods: "string", key: "string"}},
  overview: {previews: "boolean"},
  lockScreen: {showProfile: "boolean", showMusic: "boolean"},
  profile: {name: "string", image: "string"},
  idle: {enabled: "boolean", lockSeconds: "number", screenOffSeconds: "number", suspendSeconds: "number"}
};

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
  if (expected === "strings") {
    if (!Array.isArray(value) || !value.length || value.some(v => typeof v !== "string" || !v || /[\u0000\r\n]/.test(v))) throw new Error(path);
    return;
  }
  if (expected === "color") {
    if (typeof value !== "string" || !/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value)) throw new Error(path);
    return;
  }
  if (typeof value !== expected || (expected === "number" && !Number.isFinite(value))) throw new Error(path);
  if (choices[key] && !choices[key].includes(value)) throw new Error(path);
  if ((key === "scale" && (value < 0.5 || value > 3)) || (key === "margin" && (value < 0 || value > 200))
      || (key === "workspaceCount" && (!Number.isInteger(value) || value < 1 || value > 100))) throw new Error(path);
}

function argv(value, path, optional) {
  if (!Array.isArray(value) || (!optional && !value.length)
      || value.some(v => typeof v !== "string" || !v || /[\u0000\r\n]/.test(v))) throw new Error(path);
}
function parse(text, scope) {
  const value = JSON.parse(text);
  if (!value || Array.isArray(value) || typeof value !== "object") throw new Error("settings");
  if (scope !== "common" && value.frame === undefined) value.frame = "off";
  const commonKeys = ["mode", "scale", "animations", "colors", "clockFormat", "applications"];
  const schema = {};
  for (const key of Object.keys(shape))
    if (commonKeys.includes(key) === (scope === "common")) schema[key] = shape[key];
  validate(value, schema, "settings", "settings");
  if (scope === "common") {
    for (const key of Object.keys(optionalCommon)) {
      if (value[key] !== undefined) validate(value[key], optionalCommon[key], "settings." + key, key);
    }
    if (value.clipboard) {
      const c = value.clipboard;
      if (!Number.isInteger(c.historySize) || c.historySize < 1 || c.historySize > 500
          || !Number.isInteger(c.maxImageBytes) || c.maxImageBytes < 1 || c.maxImageBytes > 1073741824
          || !["paste", "copy"].includes(c.enterAction)
          || !/^[A-Za-z0-9_ +,-]*$/.test(c.pasteShortcut.mods) || !/^[A-Za-z0-9_]+$/.test(c.pasteShortcut.key)) throw new Error("clipboard preferences");
    }
    if (value.idle) {
      const times = [value.idle.lockSeconds, value.idle.screenOffSeconds, value.idle.suspendSeconds];
      if (times.some(v => !Number.isInteger(v) || v < 1 || v > 86400) || times[0] > times[1] || times[1] > times[2]) throw new Error("idle timeouts");
    }
    if (!value.providers || typeof value.providers !== "object") throw new Error("providers");
    for (const key of ["launcher", "lock", "suspend", "logout", "reboot", "poweroff"]) argv(value.providers[key], "providers." + key, true);
    if (!Array.isArray(value.modules)) throw new Error("modules");
    const ids = new Set();
    for (const module of value.modules) {
      if (!module || !/^[a-zA-Z0-9][a-zA-Z0-9_.-]*$/.test(module.id) || ids.has(module.id)
          || typeof module.path !== "string" || !module.path || /[\u0000\r\n]/.test(module.path)
          || typeof module.enabled !== "boolean" || typeof module.autostart !== "boolean") throw new Error("module registry");
      ids.add(module.id);
    }
  } else {
    if (typeof value.modules.capture !== "boolean" || !value.components || Array.isArray(value.components)) throw new Error("components");
    for (const key of Object.keys(value.modules))
      if (typeof value.components[key] !== "string" || /[\u0000\r\n]/.test(value.components[key])) throw new Error("components." + key);
  }
  return value;
}

// Merge only explicitly edited leaf paths against a fresh disk snapshot.
function at(object, path) { return path.split(".").reduce((v, k) => v === undefined ? undefined : v[k], object); }
function patch(current, baseline, changes, scope) {
  const next = JSON.parse(JSON.stringify(current));
  for (const path of Object.keys(changes)) {
    const keys = path.split(".");
    if (keys.some(k => !/^[A-Za-z][A-Za-z0-9]*$/.test(k) || ["constructor", "prototype", "__proto__"].includes(k))) throw new Error("Invalid field: " + path);
    const commonKeys = ["mode", "scale", "animations", "colors", "clockFormat", "applications"];
    const allowed = scope === "common" ? Object.assign({}, optionalCommon) : {};
    for (const key of Object.keys(shape)) if (commonKeys.includes(key) === (scope === "common")) allowed[key] = shape[key];
    let rule = allowed;
    for (const k of keys) rule = rule && typeof rule === "object" ? rule[k] : undefined;
    if (!rule || (typeof rule === "object")) throw new Error("Unsupported field: " + path);
    if (JSON.stringify(at(current, path)) !== JSON.stringify(at(baseline, path))) throw new Error("Changed externally: " + path + ". Reload before applying.");
    let target = next;
    for (const k of keys.slice(0, -1)) { if (!target[k]) target[k] = {}; target = target[k]; }
    target[keys[keys.length - 1]] = changes[path];
  }
  return parse(JSON.stringify(next), scope);
}
