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
hl = {
  dsp = dispatchers("hl.dsp"),
  config = function() end,
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
print("KEYBINDINGS_PASS")
