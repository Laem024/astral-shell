pragma ComponentBehavior: Bound
import QtQuick

Item {
  id: root
  required property FrameGeometry geometry
  required property string edge
  required property color surfaceColor
  readonly property bool horizontal: edge === "top" || edge === "bottom"
  readonly property bool curved: horizontal === !geometry.vertical
  readonly property real base: geometry.base(edge)
  readonly property real depth: base + (curved ? geometry.radius : 0)
  Canvas {
    id: canvas
    anchors.fill: parent
    // Paint in top-edge coordinates, rotating the same shape for every edge.
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections {
      target: root
      function onSurfaceColorChanged() { canvas.requestPaint(); }
      function onBaseChanged() { canvas.requestPaint(); }
      function onDepthChanged() { canvas.requestPaint(); }
    }
    Connections {
      target: root.geometry
      function onRadiusChanged() { canvas.requestPaint(); }
      function onModeChanged() { canvas.requestPaint(); }
      function onEdgeChanged() { canvas.requestPaint(); }
    }
    onPaint: {
      const ctx = getContext("2d");
      ctx.reset();
      const length = root.horizontal ? width : height;
      if (root.edge === "bottom") { ctx.translate(width, height); ctx.rotate(Math.PI); }
      else if (root.edge === "left") { ctx.translate(0, height); ctx.rotate(-Math.PI / 2); }
      else if (root.edge === "right") { ctx.translate(width, 0); ctx.rotate(Math.PI / 2); }
      ctx.fillStyle = root.surfaceColor;
      if (root.edge !== root.geometry.edge) ctx.fillRect(0, 0, length, root.base);
      if (!root.curved) return;
      const r = root.geometry.radius;
      // Full frames join the side border. Folds taper all the way back to
      // the output edge, without a straight border ending at the canvas cut.
      const t = root.geometry.mode === "full" ? root.geometry.thickness : 0;
      const b = root.base;
      ctx.beginPath();
      ctx.moveTo(0, b); ctx.lineTo(t + r, b);
      ctx.arcTo(t, b, t, b + r, r);
      ctx.lineTo(0, b + r); ctx.closePath();
      ctx.moveTo(length, b); ctx.lineTo(length - t - r, b);
      ctx.arcTo(length - t, b, length - t, b + r, r);
      ctx.lineTo(length, b + r); ctx.closePath(); ctx.fill();
    }
  }
}
