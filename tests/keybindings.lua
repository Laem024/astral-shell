-- Register bindings without dispatching any actions in the live session.
package.path = "config/hyprland/?.lua;" .. package.path
local metadata = assert(io.open("/usr/share/hypr/stubs/hl.meta.lua")):read("*a")
local function dispatchers(prefix)
  return setmetatable({}, { __index = function(_, name)
    local path = prefix .. "." .. name
    if path == "hl.dsp.window" or path == "hl.dsp.workspace" or path == "hl.dsp.group" then
      return dispatchers(path)
    end
    assert(metadata:find("---@field " .. name .. " ", 1, true), "Unknown dispatcher: " .. path)
    return function(...) return { path = path, args = {...} } end
  end })
end
local bindings = {}
local active_workspace = 2
local dispatched = {}
hl = {
  dsp = dispatchers("hl.dsp"),
  config = function() end,
  get_active_workspace = function() return { id = active_workspace } end,
  dispatch = function(action) dispatched[#dispatched + 1] = action end,
  bind = function(key, action)
    assert(not bindings[key], "Duplicate binding: " .. key)
    bindings[key] = action
  end,
}
require("modules.keybindings")
assert(bindings["SUPER + Q"].args[1] == "astral-launcher close-active")
assert(bindings["SUPER + Space"].args[1] == "astral-launcher")
assert(bindings["SUPER + L"].args[1] == "astral-lock")
assert(bindings["SUPER + Escape"].args[1] == "astral-session")
assert(bindings["SUPER + SHIFT + W"].args[1] == "astral-wallpaper carousel")
assert(bindings["SUPER + CTRL + W"].args[1] == "astral-wallpaper toggle")
assert(bindings["CTRL + SHIFT + Escape"].args[1] == "astral-monitor")
assert(bindings["SUPER + V"].args[1] == "astral-clipboard paste")
assert(bindings["SUPER + CTRL + V"].args[1] == "astral-clipboard delete")
assert(bindings["SUPER + CTRL + SHIFT + V"].args[1] == "astral-clipboard clear")
assert(bindings["SUPER + slash"].args[1] == "astral-shortcuts")
assert(bindings["ALT + Tab"].args[1] == "astral-overview alt-tab next")
assert(bindings["ALT + SHIFT + Tab"].args[1] == "astral-overview alt-tab previous")
assert(bindings["SUPER + Z"].args[1] == "astral-settings")

local workspaces = require("modules.workspaces")
workspaces.bar_count = function() return 10 end
bindings["SUPER + 1"]()
assert(#dispatched == 1 and dispatched[1].args[1].workspace == 1)
active_workspace = 1
bindings["SUPER + 1"]()
assert(#dispatched == 1, "Selecting the active workspace must not dispatch focus")
active_workspace = 11
bindings["SUPER + 1"]()
assert(#dispatched == 1, "Selecting the active workspace in another block must not dispatch focus")

print("KEYBINDINGS_PASS")
