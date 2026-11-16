import QtQuick
import QtMultimedia
import "Logic.js" as Logic

Item {
  id: root
  property string path: ""
  property bool fit: false
  property bool paused: true
  property bool primed: false
  onPathChanged: primed = false
  readonly property string kind: Logic.kind(path)
  readonly property real position: player.position
  readonly property int frame: animated.currentFrame
  signal prepared()
  signal failed(string detail)
  function markReady() { if (!primed) { primed = true; prepared(); } }
  function synchronize(leader) {
    if (kind === "video" && player.seekable && Math.abs(position - leader.position) > 120) player.position = leader.position;
    if (kind === "gif" && animated.frameCount > 0 && Math.abs(frame - leader.frame) > 1) animated.currentFrame = leader.frame % animated.frameCount;
  }
  Image {
    anchors.fill: parent
    visible: root.kind === "image"
    source: root.kind === "image" ? Logic.fileUrl(root.path) : ""
    asynchronous: true; fillMode: root.fit ? Image.PreserveAspectFit : Image.PreserveAspectCrop
    onStatusChanged: {
      if (status === Image.Ready) root.markReady();
      else if (status === Image.Error) root.failed("The image does not exist or is damaged.");
    }
  }
  AnimatedImage {
    id: animated
    anchors.fill: parent
    visible: root.kind === "gif"
    source: root.kind === "gif" ? Logic.fileUrl(root.path) : ""
    asynchronous: true; fillMode: root.fit ? Image.PreserveAspectFit : Image.PreserveAspectCrop
    playing: !root.paused
    onStatusChanged: {
      if (status === Image.Ready) root.markReady();
      else if (status === Image.Error) root.failed("The GIF does not exist or is damaged.");
    }
  }
  VideoOutput { id: video; anchors.fill: parent; visible: root.kind === "video"; fillMode: root.fit ? VideoOutput.PreserveAspectFit : VideoOutput.PreserveAspectCrop }
  MediaPlayer {
    id: player
    source: root.kind === "video" ? Logic.fileUrl(root.path) : ""
    videoOutput: video
    audioOutput: AudioOutput { muted: true; volume: 0 }
    loops: MediaPlayer.Infinite
    onMediaStatusChanged: {
      if (mediaStatus === MediaPlayer.LoadedMedia) play();
      if (mediaStatus === MediaPlayer.InvalidMedia) root.failed("The video is unavailable or its codec is not supported.");
    }
    onErrorOccurred: root.failed("Video playback failed. Check the file and installed codecs.")
  }
  Connections {
    target: video.videoSink
    function onVideoFrameChanged() {
      if (!root.primed) { if (root.paused) player.pause(); root.markReady(); }
    }
  }
  onPausedChanged: {
    if (kind !== "video" || !primed) return;
    if (paused) player.pause(); else player.play();
  }
}
