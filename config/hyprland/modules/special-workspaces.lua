local variables = require("modules.variables")

local special_workspaces = variables.special_workspaces
local applications = variables.special_workspace_apps

-- Las clases se escriben como texto exacto en las variables. Para las reglas
-- de ventana se escapan los caracteres especiales del motor de expresiones
-- regulares y se ancla la coincidencia a la clase completa.
local function class_pattern(classes)
  local pattern = {}

  for _, class in ipairs(classes) do
    pattern[#pattern + 1] = (class:gsub("([%(%)%.%%%+%-%*%?%[%]%^%${}|])", "%%%1"))
  end

  return "^(" .. table.concat(pattern, "|") .. ")$"
end

local apps_by_workspace = {}

for name, application in pairs(applications) do
  local workspace = special_workspaces[name] or name
  local classes = application.classes or {}
  apps_by_workspace[workspace] = application

  -- Mueve las aplicaciones del espacio al abrirlas. Mostrar el espacio especial
  -- es intencional: abrir la aplicación debe traerla al frente.
  if #classes > 0 then
    hl.window_rule({
      name  = "special-workspace-" .. name,
      match = { class = class_pattern(classes) },

      workspace = "special:" .. workspace,
    })
  end
end

local function has_window(application)
  local classes = {}

  for _, class in ipairs(application.classes or {}) do
    classes[class:lower()] = true
  end

  for _, window in ipairs(hl.get_windows()) do
    local class = window.class or window.initial_class
    if class and classes[class:lower()] then
      return true
    end
  end

  return false
end

-- Intenta primero los binarios instalados y después los paquetes Flatpak.
local function launch_command(application)
  local launch = application.launch or {}
  local commands = {}

  for _, binary in ipairs(launch.commands or {}) do
    commands[#commands + 1] = string.format(
      "if command -v %s >/dev/null 2>&1; then exec %s; fi", binary, binary)
  end

  for _, flatpak in ipairs(launch.flatpaks or {}) do
    commands[#commands + 1] = string.format(
      "if command -v flatpak >/dev/null 2>&1 && flatpak info %s >/dev/null 2>&1; then exec flatpak run %s; fi",
      flatpak, flatpak)
  end

  return table.concat(commands, "\n")
end

-- Al mostrar un espacio especial se abre su aplicación si está instalada y
-- todavía no tiene ninguna ventana. Las demás clases solo se mueven al
-- espacio mediante las reglas de ventana.
hl.on("workspace.special_active", function(workspace)
  if not workspace or not workspace.name then return end

  local name = workspace.name:match("^special:(.+)$")
  local application = name and apps_by_workspace[name]
  if not application then return end

  local command = launch_command(application)
  if command == "" or has_window(application) then return end

  hl.exec_cmd(command)
end)
