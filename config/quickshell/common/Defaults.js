.pragma library

const common = {
  "mode": "dark",
  "scale": 1,
  "animations": true,
  "colors": {
    "light": {
      "background": "#EEF2EF",
      "surface": "#FBFCFA",
      "text": "#141B1D",
      "muted": "#5A6764",
      "cyan": "#17675A",
      "lavender": "#3B4A7A",
      "gold": "#8A5B16",
      "alert": "#A9361F"
    },
    "dark": {
      "background": "#0E1113",
      "surface": "#171C1F",
      "text": "#E7ECE9",
      "muted": "#8D9994",
      "cyan": "#7FD0BF",
      "lavender": "#A9B5D9",
      "gold": "#E5B873",
      "alert": "#F08C7B"
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
