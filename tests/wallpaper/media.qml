pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import Quickshell
import "../../config/quickshell/astral-wallpaper" as Wallpaper

Window {
  id: root
  width: 480; height: 300; visible: true
  property var files: ["00 first.png", "still.jpeg", "still.bmp", "still.webp", "nested/spaces #?% $(touch INJECTED).png", "motion.gif", "motion.mp4", "motion.webm", "motion.mkv", "deleted.png", "broken.png"]
  property var current: null
  property int index: -1
  property int elapsed: 0
  property bool completed: false
  function check(value, message) { if (!value) { console.error("WALLPAPER_FAIL: " + message); Qt.exit(1); } }
  Component {
    id: media
    Wallpaper.WallpaperMedia {
      anchors.fill: parent
      paused: false
      onPrepared: { root.check(root.index < 9, "missing/damaged file accepted"); root.completed = true; }
      onFailed: detail => { root.check(root.index >= 9, root.files[root.index] + ": " + detail); root.completed = true; }
    }
  }
  Timer {
    interval: 100; running: true; repeat: true; triggeredOnStart: true
    onTriggered: {
      if (++root.elapsed > 150) root.check(false, "media timeout " + root.files[root.index]);
      if (root.current && !root.completed) return;
      if (root.current) root.current.destroy();
      if (++root.index >= root.files.length) { console.log("WALLPAPER_MEDIA_PASS (all supported formats, special paths, missing and damaged files)"); Qt.quit(); return; }
      root.completed = false;
      root.current = media.createObject(root, {path: Quickshell.env("HOME") + "/Pictures/Wallpapers/" + root.files[root.index]});
    }
  }
}
