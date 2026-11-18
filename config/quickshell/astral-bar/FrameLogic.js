.pragma library

function calculate(settings, tokens) {
  const mode = settings.frame || "off";
  const active = mode !== "off";
  const edge = settings.position;
  const vertical = edge === "left" || edge === "right";
  const margin = active ? 0 : settings.margin;
  const thickness = 8 * tokens.scale;
  const radius = tokens.panelRadius * tokens.scale;
  const barSize = (vertical ? tokens.verticalSize : tokens.horizontalSize) * tokens.scale;
  return {
    mode: mode, active: active, edge: edge, vertical: vertical,
    margin: margin, thickness: thickness, radius: radius, barSize: barSize,
    reservation: function(side) {
      // Curves occupy only the corners, not an extra strip across the output.
      // Hyprland supplies the ordinary window gap outside these solid edges.
      if (side === edge) return barSize + margin;
      return mode === "full" ? thickness : 0;
    },
    base: function(side) { return side === edge ? barSize : mode === "full" ? thickness : 0; }
  };
}
