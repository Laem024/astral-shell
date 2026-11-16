.pragma library

const palette = {
  background: "color", surface: "color", text: "color", muted: "color",
  cyan: "color", lavender: "color", gold: "color", alert: "color"
};
const shape = {
  position: "string", mode: "string", scale: "number", margin: "number", animations: "boolean",
  colors: { light: palette, dark: palette },
  clockFormat: "string", workspaceCount: "number", workspaceDisplay: "string",
  modules: {
    logo: "boolean", workspaces: "boolean", window: "boolean", clock: "boolean",
    music: "boolean", network: "boolean", audio: "boolean", battery: "boolean",
    notifications: "boolean", tray: "boolean"
  },
  applications: { fileManager: "strings", terminal: "strings", videoPlayer: "strings" },
  weather: { temperatureUnit: "string", windUnit: "string" },
  logo: { glyph: "string", image: "string" }
};
const choices = {
  position: ["top", "bottom", "left", "right"], mode: ["light", "dark"],
  clockFormat: ["12h", "24h"], workspaceDisplay: ["icons", "numbers"],
  temperatureUnit: ["celsius", "fahrenheit"], windUnit: ["kmh", "mph", "ms", "kn"]
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
    if (typeof value !== "string" || !/^#[0-9a-fA-F]{3,8}$/.test(value)) throw new Error(path);
    return;
  }
  if (typeof value !== expected || (expected === "number" && !Number.isFinite(value))) throw new Error(path);
  if (choices[key] && !choices[key].includes(value)) throw new Error(path);
  if ((key === "scale" && (value < 0.5 || value > 3)) || (key === "margin" && (value < 0 || value > 200))
      || (key === "workspaceCount" && (!Number.isInteger(value) || value < 1 || value > 100))) throw new Error(path);
}

function parse(text) {
  const value = JSON.parse(text);
  validate(value, shape, "settings", "settings");
  return value;
}
