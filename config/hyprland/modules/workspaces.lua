local M = {}

local DEFAULT_COUNT = 10
local MIN_COUNT = 1
local MAX_COUNT = 100

-- Query the installed destination on each key press, including named/partial trees.
function M.bar_count()
  local pipe = io.popen("timeout 1 astral-shell workspace-count 2>/dev/null", "r")
  if not pipe then return DEFAULT_COUNT end
  local text = pipe:read("*a")
  local ok = pipe:close()
  if not ok or type(text) ~= "string" then return DEFAULT_COUNT end
  local digits = text:match("^%s*(%d+)%s*$")
  local count = digits and tonumber(digits)
  if not count or count < MIN_COUNT or count > MAX_COUNT then return DEFAULT_COUNT end
  return count
end

-- Con un espacio especial visible se conserva el espacio normal que hay
-- debajo, que es el bloque que muestra la barra.
function M.active_id()
  local workspace = hl and hl.get_active_workspace and hl.get_active_workspace() or nil
  if workspace and workspace.id and workspace.id > 0 then return workspace.id end
  local monitor = hl and hl.get_active_monitor and hl.get_active_monitor() or nil
  if monitor and monitor.active_workspace and monitor.active_workspace.id
    and monitor.active_workspace.id > 0 then
    return monitor.active_workspace.id
  end
  return 1
end

function M.target(slot, count)
  count = count or M.bar_count()
  if not count or count < MIN_COUNT or slot < 1 or slot > count then return nil end
  local base = math.floor((M.active_id() - 1) / count) * count
  return base + slot
end

return M
