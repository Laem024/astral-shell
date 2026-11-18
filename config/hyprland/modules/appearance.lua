-- Palette from docs/design-system.md. Set mode to "light" for light mode.
local mode = "dark"

local palette = {
  dark = {
    cyan     = "7FD0BF",
    lavender = "A9B5D9",
    muted    = "8D9994",
    shadow   = 0xee0E1113,
  },
  light = {
    cyan     = "17675A",
    lavender = "3B4A7A",
    muted    = "5A6764",
    shadow   = 0x55141B1D,
  },
}

local colors = palette[mode]

hl.config({
  general = {
    gaps_in  = 5,
    gaps_out = 10,

    border_size = 2,

    col = {
      active_border   = { colors = {"rgba(" .. colors.cyan .. "ee)", "rgba(" .. colors.lavender .. "ee)"}, angle = 45 },
      inactive_border = "rgba(" .. colors.muted .. "66)",
    },

    resize_on_border = true,

    snap = {
      enabled = true,
    },

    allow_tearing = false,
  },

  decoration = {
    rounding       = 14,
    rounding_power = 2,

    active_opacity   = 1.0,
    inactive_opacity = 1.0,

    dim_inactive = true,
    dim_strength = 0.12,

    shadow = {
      enabled      = true,
      range        = 4,
      render_power = 3,
      color        = colors.shadow,
    },

    blur = {
      enabled   = true,
      size      = 3,
      passes    = 1,
      vibrancy  = 0.1696,
    },
  },

  misc = {
    force_default_wallpaper  = 0,
    disable_hyprland_logo    = true,
    disable_splash_rendering = true,

    -- VRR solo en pantalla completa: eDP-1 lo soporta; HDMI-A-1 no se ve afectado.
    vrr = 2,

    focus_on_activate            = true,
    animate_manual_resizes       = true,
    animate_mouse_windowdragging = true,
  },

  layers = {
    allow_new_top_layers_over_existing_fullscreen = true,
  },
})
