local variables = require("modules.variables")

-- Coloca el monitor de recursos en su espacio especial y lo muestra a pantalla completa.
hl.window_rule({
  name  = "astral-monitor-workspace",
  match = { class = "astral-monitor" },

  workspace   = "special:" .. variables.special_workspaces.resources,
  float       = true,
  fullscreen  = true,
  decorate    = false,
  border_size = 0,
  rounding    = 0,
  no_anim     = true,
  no_shadow   = true,
})

-- Calculadora y mezclador de audio: ventanas flotantes centradas para no
-- competir con el mosaico.
hl.window_rule({
  name  = "calculator-floating",
  match = { class = "qalculate-gtk" },

  float  = true,
  center = true,
  size   = { 460, 620 },
})

hl.window_rule({
  name  = "pavucontrol-floating",
  match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol)$" },

  float  = true,
  center = true,
  size   = { "monitor_w*0.45", "monitor_h*0.55" },
})

-- Ignora las solicitudes de maximización de las aplicaciones.
hl.window_rule({
  name  = "suppress-maximize-events",
  match = { class = ".*" },

  suppress_event = "maximize",
})

-- Evita problemas de arrastre con ventanas XWayland sin título ni clase.
hl.window_rule({
  name  = "fix-xwayland-drags",
  match = {
    class      = "^$",
    title      = "^$",
    xwayland   = true,
    float      = true,
    fullscreen = false,
    pin        = false,
  },

  no_focus = true,
})

hl.window_rule({
  name  = "move-hyprland-run",
  match = { class = "hyprland-run" },

  move  = "10 monitor_h-120",
  float = true,
})
