import QtQuick

// Focus is a point in the original image, independent of the viewport size.
Item {
  id: root
  property alias source: image.source
  readonly property alias status: image.status
  property real zoom: 1
  property real focusX: 0.5
  property real focusY: 0.5
  readonly property real imageWidth: image.implicitWidth
  readonly property real imageHeight: image.implicitHeight
  readonly property real coverScale: imageWidth > 0 && imageHeight > 0
    ? Math.max(width / imageWidth, height / imageHeight) * Math.max(1, Math.min(4, zoom)) : 1
  clip: true

  function pan(dx: real, dy: real): void {
    if (image.width <= 0 || image.height <= 0) return;
    const x = Math.max(width - image.width, Math.min(0, image.x + dx));
    const y = Math.max(height - image.height, Math.min(0, image.y + dy));
    focusX = (width / 2 - x) / image.width;
    focusY = (height / 2 - y) / image.height;
  }
  function reset(): void { zoom = 1; focusX = 0.5; focusY = 0.5; }

  Image {
    id: image
    width: root.imageWidth * root.coverScale
    height: root.imageHeight * root.coverScale
    x: Math.max(root.width - width, Math.min(0, root.width / 2 - root.focusX * width))
    y: Math.max(root.height - height, Math.min(0, root.height / 2 - root.focusY * height))
    asynchronous: true
    cache: false
  }
}
