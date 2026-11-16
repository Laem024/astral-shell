local applications = {
  "astral-shell",

  -- Manage removable devices without opening a file manager window.
  'command -v thunar >/dev/null 2>&1 && thunar --daemon',
}

hl.on("hyprland.start", function()
  -- Import session variables before starting Quickshell and user services.
  -- Portals and GVfs activate through D-Bus on demand.
  hl.exec_cmd([[

    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
      dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE XDG_STATE_HOME XDG_CONFIG_HOME
    else
      systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE XDG_STATE_HOME XDG_CONFIG_HOME
    fi

    systemctl --user start astral-caffeine.service

  ]])

  for _, command in ipairs(applications) do
    hl.exec_cmd(command)
  end
end)
