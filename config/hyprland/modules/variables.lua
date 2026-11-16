return {
  terminal = "kitty",
  file_manager = "thunar",
  browser = "firefox",
  code_editor = "code",
  calculator = "qalculate-gtk",
  notepad = "mousepad",

  playerctl = "playerctl",
  wpctl = "wpctl",
  brightnessctl = "brightnessctl",

  main_mod = "SUPER",

  special_workspaces = {
    magic = "magic",
    music = "music",
    communication = "communication",
    resources = "resources",
  },

  -- Aplicaciones propias de cada espacio especial. `classes` contiene las
  -- clases (app_id) que se mueven al espacio al abrirse; añade ahí cualquier
  -- aplicación nueva. `launch` solo se ejecuta al mostrar el espacio si no hay
  -- ninguna ventana de la lista: primero los binarios nativos y después los
  -- paquetes Flatpak.
  special_workspace_apps = {
    communication = {
      classes = {
        "discord",
        "Discord",
        "com.discordapp.Discord",
        "discord-canary",
        "DiscordCanary",
        "vesktop",
        "Vesktop",
        "dev.vencord.Vesktop",
        "equibop",
        "Equibop",
        "signal",
        "Signal",
        "org.signal.Signal",
        "telegram",
        "Telegram",
        "org.telegram.desktop",
        "slack",
        "Slack",
        "com.slack.Slack",
        "element",
        "Element",
        "im.riot.Riot",
        "teams-for-linux",
        "zoom",
        "Zoom",
        "us.zoom.Zoom",
        "whatsapp-for-linux",
      },

      launch = {
        commands = { "discord" },
        flatpaks = { "com.discordapp.Discord" },
      },
    },

    music = {
      classes = {
        "spotify",
        "Spotify",
        "com.spotify.Client",
        "cider",
        "Cider",
        "feishin",
        "Feishin",
        "tidal-hifi",
        "TIDAL",
        "youtube-music",
        "YouTube Music",
        "nuclear",
        "Nuclear",
      },

      launch = {
        commands = { "spotify", "spotify-launcher" },
        flatpaks = { "com.spotify.Client" },
      },
    },
  },
}
