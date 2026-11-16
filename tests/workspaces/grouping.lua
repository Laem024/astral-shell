local module_path = assert(arg[1], "missing workspaces.lua path")
local workspaces = dofile(module_path)
local config = assert(os.getenv("XDG_CONFIG_HOME"), "XDG_CONFIG_HOME is required")
local settings = config .. "/quickshell/selected/settings.json"

local function write_count(value)
  local file = assert(io.open(settings, "w"))
  file:write('{"workspaceCount":', tostring(value), "}\n")
  file:close()
end

local function set_active(workspace_id, monitor_id)
  _G.hl = {
    get_active_workspace = function()
      return workspace_id and { id = workspace_id } or nil
    end,
    get_active_monitor = function()
      return { active_workspace = { id = monitor_id or 0 } }
    end,
  }
end

local function expect(actual, expected, label)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

os.remove(settings)
expect(workspaces.bar_count(), 10, "missing settings falls back to 10")
for _, count in ipairs({1, 5, 10, 100}) do
  write_count(count)
  expect(workspaces.bar_count(), count, "valid count")
end
write_count(5)
expect(workspaces.bar_count(), 5, "workspaceCount is read")
write_count('"5"')
expect(workspaces.bar_count(), 10, "string rejected")
write_count(true)
expect(workspaces.bar_count(), 10, "boolean rejected")
write_count(0)
expect(workspaces.bar_count(), 10, "zero is rejected")
write_count(1.5)
expect(workspaces.bar_count(), 10, "fraction rejected")
write_count(101)
expect(workspaces.bar_count(), 10, "values above 100 are rejected")

write_count(10)
set_active(10)
expect(workspaces.target(1), 1, "workspace 10 slot 1")
expect(workspaces.target(10), 10, "workspace 10 slot 10")
set_active(11)
expect(workspaces.target(1), 11, "workspace 11 starts the next block")
expect(workspaces.target(10), 20, "workspace 11 slot 10")
expect(workspaces.target(11), nil, "slots above the block size are ignored")
set_active(21)
expect(workspaces.target(1), 21, "workspace 21 starts the third block")

write_count(5)
set_active(6)
expect(workspaces.target(1), 6, "five-slot block starts at 6")
expect(workspaces.target(5), 10, "five-slot block ends at 10")
expect(workspaces.target(6), nil, "sixth slot is outside a five-slot block")

write_count(10)
set_active(-1, 11)
expect(workspaces.target(1), 11, "special workspace falls back to the monitor workspace")

print("WORKSPACES_PASS")
