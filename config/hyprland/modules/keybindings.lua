local variables = require("modules.variables")
local workspaces = require("modules.workspaces")
local main_mod = variables.main_mod

local function described(label)
  return { description = label }
end

hl.bind(main_mod .. " + Return", hl.dsp.exec_cmd(variables.terminal), described("Apps · Terminal"))
hl.bind(main_mod .. " + E", hl.dsp.exec_cmd(variables.file_manager), described("Apps · File manager"))
hl.bind(main_mod .. " + W", hl.dsp.exec_cmd(variables.browser), described("Apps · Browser"))
hl.bind(main_mod .. " + C", hl.dsp.exec_cmd(variables.code_editor), described("Apps · Code editor"))
hl.bind(main_mod .. " + R", hl.dsp.exec_cmd(variables.calculator), described("Apps · Calculator"))
hl.bind(main_mod .. " + N", hl.dsp.exec_cmd(variables.notepad), described("Apps · Notepad"))

hl.bind(main_mod .. " + Space", hl.dsp.exec_cmd("astral-launcher"), described("Apps · Launcher"))
hl.bind(main_mod .. " + L", hl.dsp.exec_cmd("astral-lock"), described("Session · Lock"))
hl.bind(main_mod .. " + Escape", hl.dsp.exec_cmd("astral-session"), described("Session · Actions"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("astral-session"), described("Session · Actions"))

hl.bind(main_mod .. " + SHIFT + W", hl.dsp.exec_cmd("astral-wallpaper carousel"), described("Wallpaper · Carousel"))
hl.bind(main_mod .. " + CTRL + W", hl.dsp.exec_cmd("astral-wallpaper toggle"), described("Wallpaper · Panel"))

hl.bind(main_mod .. " + Q", hl.dsp.exec_cmd("astral-launcher close-active"), described("Windows · Close overlay or active window"))
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), described("Windows · Maximize"))
hl.bind(main_mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), described("Windows · Fullscreen"))
hl.bind(main_mod .. " + T", hl.dsp.window.float({ action = "toggle" }), described("Windows · Toggle floating"))
hl.bind(main_mod .. " + P", hl.dsp.window.pseudo(), described("Windows · Toggle pseudo-tiling"))
hl.bind(main_mod .. " + J", hl.dsp.layout("togglesplit"), described("Windows · Toggle split"))

hl.config({
  binds = {
    window_direction_monitor_fallback = true,
    workspace_back_and_forth           = true,
    allow_workspace_cycles             = true,
    movefocus_cycles_fullscreen        = true,
  },
  general = {
    no_focus_fallback = true,
  },
})

hl.bind(main_mod .. " + left",  hl.dsp.focus({ direction = "left" }), described("Windows · Focus left"))
hl.bind(main_mod .. " + right", hl.dsp.focus({ direction = "right" }), described("Windows · Focus right"))
hl.bind(main_mod .. " + up",    hl.dsp.focus({ direction = "up" }), described("Windows · Focus up"))
hl.bind(main_mod .. " + down",  hl.dsp.focus({ direction = "down" }), described("Windows · Focus down"))

hl.bind(main_mod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }), described("Windows · Move window left"))
hl.bind(main_mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), described("Windows · Move window right"))
hl.bind(main_mod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }), described("Windows · Move window up"))
hl.bind(main_mod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }), described("Windows · Move window down"))

hl.bind(main_mod .. " + Tab",         hl.dsp.window.cycle_next(), described("Windows · Next window"))
hl.bind(main_mod .. " + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), described("Windows · Previous window"))
hl.bind(main_mod .. " + grave",       hl.dsp.focus({ last = true }), described("Windows · Last focused window"))

hl.bind(main_mod .. " + ALT + left",  hl.dsp.window.resize({ x = -50, y = 0, relative = true }), described("Windows · Resize left"))
hl.bind(main_mod .. " + ALT + right", hl.dsp.window.resize({ x = 50,  y = 0, relative = true }), described("Windows · Resize right"))
hl.bind(main_mod .. " + ALT + up",    hl.dsp.window.resize({ x = 0, y = -50, relative = true }), described("Windows · Resize up"))
hl.bind(main_mod .. " + ALT + down",  hl.dsp.window.resize({ x = 0, y = 50,  relative = true }), described("Windows · Resize down"))

hl.bind(main_mod .. " + ALT + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }), described("Windows · Swap left"))
hl.bind(main_mod .. " + ALT + SHIFT + right", hl.dsp.window.swap({ direction = "right" }), described("Windows · Swap right"))
hl.bind(main_mod .. " + ALT + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }), described("Windows · Swap up"))
hl.bind(main_mod .. " + ALT + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }), described("Windows · Swap down"))

hl.bind(main_mod .. " + SHIFT + T", function()
  hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
  hl.dispatch(hl.dsp.window.center())
end, described("Windows · Float and center"))
hl.bind(main_mod .. " + SHIFT + P", hl.dsp.window.pin({ action = "toggle" }), described("Windows · Pin window"))

hl.bind(main_mod .. " + comma",         hl.dsp.focus({ monitor = "-" }), described("Monitors · Focus previous"))
hl.bind(main_mod .. " + period",        hl.dsp.focus({ monitor = "+" }), described("Monitors · Focus next"))
hl.bind(main_mod .. " + SHIFT + comma",  hl.dsp.window.move({ monitor = "-", follow = true }), described("Monitors · Move window to previous"))
hl.bind(main_mod .. " + SHIFT + period", hl.dsp.window.move({ monitor = "+", follow = true }), described("Monitors · Move window to next"))

hl.bind(main_mod .. " + G",                  hl.dsp.group.toggle(), described("Windows · Group windows"))
hl.bind(main_mod .. " + SHIFT + G",          hl.dsp.window.move({ out_of_group = true }), described("Windows · Leave group"))
hl.bind(main_mod .. " + CTRL + Tab",         hl.dsp.group.next(), described("Windows · Next group"))
hl.bind(main_mod .. " + CTRL + SHIFT + Tab", hl.dsp.group.prev(), described("Windows · Previous group"))

hl.bind(main_mod .. " + CTRL + left",  hl.dsp.focus({ workspace = "-1" }), described("Workspaces · Previous workspace"))
hl.bind(main_mod .. " + CTRL + right", hl.dsp.focus({ workspace = "+1" }), described("Workspaces · Next workspace"))
hl.bind(main_mod .. " + CTRL + up",    hl.dsp.focus({ workspace = "-1" }), described("Workspaces · Previous workspace"))
hl.bind(main_mod .. " + CTRL + down",  hl.dsp.focus({ workspace = "+1" }), described("Workspaces · Next workspace"))

hl.bind(main_mod .. " + CTRL + SHIFT + left",  hl.dsp.window.move({ workspace = "-1", follow = true }), described("Workspaces · Move window to previous workspace"))
hl.bind(main_mod .. " + CTRL + SHIFT + right", hl.dsp.window.move({ workspace = "+1", follow = true }), described("Workspaces · Move window to next workspace"))
hl.bind(main_mod .. " + CTRL + SHIFT + up",    hl.dsp.window.move({ workspace = "-1", follow = true }), described("Workspaces · Move window to previous workspace"))
hl.bind(main_mod .. " + CTRL + SHIFT + down",  hl.dsp.window.move({ workspace = "+1", follow = true }), described("Workspaces · Move window to next workspace"))

for i = 1, 10 do
  local key = i % 10
  hl.bind(main_mod .. " + " .. key, function()
    local target = workspaces.target(i)
    if target then hl.dispatch(hl.dsp.focus({ workspace = target })) end
  end, described("Workspaces · Go to slot " .. key))
  hl.bind(main_mod .. " + SHIFT + " .. key, function()
    local target = workspaces.target(i)
    if target then
      hl.dispatch(hl.dsp.window.move({ workspace = target, follow = true }))
    end
  end, described("Workspaces · Move window to slot " .. key))
end


local special_workspaces = variables.special_workspaces

hl.bind(main_mod .. " + S",         hl.dsp.workspace.toggle_special(special_workspaces.magic), described("Workspaces · Magic workspace"))
hl.bind(main_mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:" .. special_workspaces.magic, follow = true }), described("Workspaces · Move window to magic workspace"))
hl.bind(main_mod .. " + M",         hl.dsp.workspace.toggle_special(special_workspaces.music), described("Workspaces · Music workspace"))
hl.bind(main_mod .. " + SHIFT + M", hl.dsp.window.move({ workspace = "special:" .. special_workspaces.music, follow = true }), described("Workspaces · Move window to music workspace"))
hl.bind(main_mod .. " + D",         hl.dsp.workspace.toggle_special(special_workspaces.communication), described("Workspaces · Communication workspace"))
hl.bind(main_mod .. " + SHIFT + D", hl.dsp.window.move({ workspace = "special:" .. special_workspaces.communication, follow = true }), described("Workspaces · Move window to communication workspace"))

hl.bind("CTRL + SHIFT + Escape", hl.dsp.exec_cmd("astral-monitor"), described("System · Resource monitor"))

hl.bind(main_mod .. " + ALT + Page_Up",   hl.dsp.exec_cmd(variables.playerctl .. " previous"), described("Media · Previous track"))
hl.bind(main_mod .. " + ALT + Page_Down", hl.dsp.exec_cmd(variables.playerctl .. " next"), described("Media · Next track"))
hl.bind(main_mod .. " + ALT + space",     hl.dsp.exec_cmd(variables.playerctl .. " play-pause"), described("Media · Play or pause"))
hl.bind(main_mod .. " + ALT + M",         hl.dsp.exec_cmd(variables.wpctl .. " set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), described("Media · Mute microphone"))
hl.bind(main_mod .. " + ALT + 0",         hl.dsp.exec_cmd(variables.wpctl .. " set-mute @DEFAULT_AUDIO_SINK@ toggle"), described("Media · Mute output"))
hl.bind(main_mod .. " + ALT + minus",     hl.dsp.exec_cmd(variables.wpctl .. " set-volume @DEFAULT_AUDIO_SINK@ 5%-"), described("Media · Volume down"))
hl.bind(main_mod .. " + ALT + equal",     hl.dsp.exec_cmd(variables.wpctl .. " set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), described("Media · Volume up"))

hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), described("Workspaces · Next workspace (wheel)"))
hl.bind(main_mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), described("Workspaces · Previous workspace (wheel)"))

hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Mouse · Drag window" })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Mouse · Resize window" })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(variables.wpctl .. " set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Media · Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(variables.wpctl .. " set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Media · Volume down" })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd(variables.wpctl .. " set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true, description = "Media · Mute output" })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd(variables.wpctl .. " set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true, description = "Media · Mute microphone" })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd(variables.brightnessctl .. " -e4 -n2 set 5%+"),                  { locked = true, repeating = true, description = "Media · Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(variables.brightnessctl .. " -e4 -n2 set 5%-"),                 { locked = true, repeating = true, description = "Media · Brightness down" })

hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(variables.playerctl .. " next"),       { locked = true, description = "Media · Next track (media key)" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(variables.playerctl .. " play-pause"), { locked = true, description = "Media · Play or pause (media key)" })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(variables.playerctl .. " play-pause"), { locked = true, description = "Media · Play or pause (media key)" })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(variables.playerctl .. " previous"),   { locked = true, description = "Media · Previous track (media key)" })

hl.bind(main_mod .. " + V", hl.dsp.exec_cmd("astral-clipboard paste"), described("Clipboard · Paste from history"))
hl.bind(main_mod .. " + CTRL + V", hl.dsp.exec_cmd("astral-clipboard delete"), described("Clipboard · Delete entries"))
hl.bind(main_mod .. " + CTRL + SHIFT + V", hl.dsp.exec_cmd("astral-clipboard clear"), described("Clipboard · Clear history"))
hl.bind(main_mod .. " + slash", hl.dsp.exec_cmd("astral-shortcuts"), described("Astral · Keyboard shortcuts"))
hl.bind("ALT + Tab", hl.dsp.exec_cmd("astral-overview alt-tab next"), described("Workspaces · Overview next"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.exec_cmd("astral-overview alt-tab previous"), described("Workspaces · Overview previous"))
