import QtQuick
import QtTest
import "../../config/quickshell/common/Defaults.js" as Defaults
import "../../config/quickshell/common/Validation.js" as Validation
import "../../config/quickshell/astral-bar/FrameLogic.js" as Logic

TestCase {
  name: "BarFrame"
  QtObject { id: settings; property var value: Object.assign({}, Defaults.common, Defaults.bar) }
  readonly property var geometry: Logic.calculate(settings.value, {scale: settings.value.scale, panelRadius: 20, horizontalSize: 64, verticalSize: 76})
  function test_geometry_data() {
    const rows = [];
    for (const frame of ["off", "folds", "full"])
      for (const position of ["top", "bottom", "left", "right"])
        for (const scale of [0.5, 1, 1.25, 3])
          rows.push({tag: frame + "-" + position + "-" + scale, frame: frame, position: position, scale: scale});
    return rows;
  }
  function test_geometry(row) {
    settings.value = Object.assign({}, Defaults.common, Defaults.bar, row, {margin: 17});
    compare(geometry.active, row.frame !== "off");
    compare(geometry.margin, row.frame === "off" ? 17 : 0);
    compare(geometry.thickness, 8 * row.scale);
    compare(geometry.radius, 20 * row.scale);
    const size = ["left", "right"].includes(row.position) ? 76 : 64;
    compare(geometry.barSize, size * row.scale);
    for (const edge of ["top", "bottom", "left", "right"]) {
      const main = edge === row.position;
      compare(geometry.base(edge), main ? size * row.scale : row.frame === "full" ? 8 * row.scale : 0);
      compare(geometry.reservation(edge), main ? size * row.scale + (row.frame === "off" ? 17 : 0)
        : row.frame === "full" ? 8 * row.scale : 0);
    }
    // A live transition recovers the user's saved margin without rewriting it.
    settings.value = Object.assign({}, settings.value, {frame: "off"});
    compare(geometry.margin, 17);
    compare(settings.value.margin, 17);
    compare(geometry.reservation(row.position), size * row.scale + 17);
  }
  function test_radius_does_not_push_windows_away() {
    for (const frame of ["folds", "full"])
      for (const position of ["top", "bottom", "left", "right"]) {
        const value = Object.assign({}, Defaults.common, Defaults.bar, {frame: frame, position: position});
        const small = Logic.calculate(value, {scale: 1, panelRadius: 10, horizontalSize: 64, verticalSize: 76});
        const large = Logic.calculate(value, {scale: 1, panelRadius: 40, horizontalSize: 64, verticalSize: 76});
        for (const side of ["top", "bottom", "left", "right"])
          compare(small.reservation(side), large.reservation(side), frame + " " + position + " " + side);
        compare(small.reservation(position), small.barSize);
      }
  }
  function test_validation() {
    const legacy = Object.assign({}, Defaults.bar);
    delete legacy.frame;
    compare(Validation.parse(JSON.stringify(legacy), "bar").frame, "off");
    for (const frame of ["off", "folds", "full"])
      compare(Validation.parse(JSON.stringify(Object.assign({}, legacy, {frame: frame})), "bar").frame, frame);
    for (const frame of ["", "invalid", "FULL", 0, false, null, [], {}]) {
      let rejected = false;
      try { Validation.parse(JSON.stringify(Object.assign({}, legacy, {frame: frame})), "bar"); }
      catch (_) { rejected = true; }
      verify(rejected, "invalid frame accepted: " + frame);
    }
  }
}
