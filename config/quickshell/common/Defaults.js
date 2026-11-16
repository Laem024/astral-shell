.pragma library

const common = {
  "mode": "dark",
  "scale": 1,
  "animations": true,
  "colors": {
    "light": {
      "background": "#EEEDE6",
      "surface": "#F8F6EF",
      "text": "#202C2A",
      "muted": "#4F5D59",
      "cyan": "#235C50",
      "lavender": "#4B5264",
      "gold": "#745020",
      "alert": "#A33420"
    },
    "dark": {
      "background": "#151918",
      "surface": "#202629",
      "text": "#F4EEDF",
      "muted": "#B1B5AD",
      "cyan": "#B1D7CB",
      "lavender": "#C6CCD2",
      "gold": "#E4B882",
      "alert": "#FF957C"
    }
  },
  "workspaceCount": 10,
  "clipboard": {"historySize": 50, "enterAction": "paste", "pasteShortcut": {"mods": "CTRL", "key": "v"}, "maxImageBytes": 26214400},
  "overview": {"previews": true},
  "clockFormat": "12h",
  "lockScreen": {"showProfile": true, "showMusic": true},
  "profile": {"name": "", "image": ""},
  "idle": {"enabled": true, "lockSeconds": 300, "screenOffSeconds": 600, "suspendSeconds": 900},
  "applications": {
    "fileManager": [
      "thunar"
    ],
    "terminal": [
      "kitty"
    ],
    "videoPlayer": [
      "haruna"
    ]
  },
  "providers": {
    "launcher": ["astral-launcher"],
    "lock": ["astral-lock", "lock"],
    "suspend": ["astral-lock", "suspend"],
    "logout": ["astral-lock", "logout"],
    "reboot": ["astral-lock", "reboot"],
    "poweroff": ["astral-lock", "poweroff"]
  },
  "modules": [
    {"id": "astral-clipboard", "path": "clipboard.qml", "enabled": true, "autostart": true},
    {"id": "astral-overview", "path": "overview.qml", "enabled": true, "autostart": true},
    {"id": "astral-shortcuts", "path": "shortcuts.qml", "enabled": true, "autostart": true},

    {"id":"astral-lock","path":"lock.qml","enabled":true,"autostart":false},
    {"id":"astral-idle","path":"idle.qml","enabled":true,"autostart":true},
    {"id":"astral-session","path":"session.qml","enabled":true,"autostart":true},
    {"id": "astral-polkit", "path": "polkit.qml", "enabled": true, "autostart": true},
    {
      "id": "astral-bar",
      "path": "bar.qml",
      "enabled": true,
      "autostart": true
    },
    {"id": "astral-launcher", "path": "launcher.qml", "enabled": true, "autostart": true},
    {"id": "astral-wallpaper", "path": "wallpaper.qml", "enabled": true, "autostart": true}
  ]
};
const bar = {
  "position": "top",
  "margin": 8,
  "workspaceDisplay": "icons",
  "modules": {
    "logo": true,
    "workspaces": true,
    "window": true,
    "clock": true,
    "music": true,
    "network": true,
    "audio": true,
    "battery": true,
    "notifications": true,
    "tray": true,
    "capture": true
  },
  "weather": {
    "temperatureUnit": "celsius",
    "windUnit": "kmh"
  },
  "logo": {
    "glyph": "",
    "image": ""
  },
  "components": {
    "logo": "",
    "workspaces": "",
    "window": "",
    "clock": "",
    "music": "",
    "network": "",
    "audio": "",
    "battery": "",
    "notifications": "",
    "tray": "",
    "capture": ""
  }
};
