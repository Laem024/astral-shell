pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Instantiable core so tests use simulated players without controlling session media.
Scope {
  id: root
  property var rawPlayers: []
  readonly property var players: distinctPlayers(rawPlayers)
  readonly property var playerOptions: players.map(p => {
    const name = p.identity || p.dbusName;
    const repeated = players.filter(other => (other.identity || other.dbusName) === name).length > 1;
    return {name: repeated ? name + " · " + p.dbusName.replace(/^org\.mpris\.MediaPlayer2\./, "") : name, key: p.dbusName};
  })
  property var player: null
  property string manualName: ""
  readonly property bool automatic: manualName === ""
  readonly property string title: player ? player.trackTitle || "Unknown title" : "Nothing playing"
  readonly property string artist: player ? player.trackArtist || "Unknown artist" : "No MPRIS player"
  readonly property string album: player ? player.trackAlbum : ""
  readonly property string artwork: player ? player.trackArtUrl : ""
  readonly property string application: player ? player.identity || player.dbusName : "No player"
  readonly property bool playing: !!player && player.isPlaying
  readonly property real position: player && player.positionSupported && isFinite(player.position) ? Math.max(0, player.position) : 0
  readonly property real length: player && player.lengthSupported && isFinite(player.length) && player.length > 0 ? player.length : 0
  readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0
  readonly property bool canControl: !!player && player.canControl
  readonly property bool canPrevious: canControl && player.canGoPrevious
  readonly property bool canNext: canControl && player.canGoNext
  readonly property bool canToggle: canControl && player.canTogglePlaying
  readonly property bool canSeek: canControl && player.canSeek && player.positionSupported && length > 0
  readonly property bool canShuffle: canControl && player.shuffleSupported
  readonly property bool canRepeat: canControl && player.loopSupported
  readonly property bool shuffle: !!player && player.shuffle
  readonly property string repeatMode: !player || player.loopState === MprisLoopState.None ? "Off" : player.loopState === MprisLoopState.Track ? "Track" : "Playlist"

  function isProxy(p) {
    return /^org\.mpris\.MediaPlayer2\.playerctld(?:\.|$)/.test(p.dbusName);
  }
  function distinctPlayers(source) {
    const names = new Set();
    const unique = source.filter(p => {
      if (!p || !p.dbusName || names.has(p.dbusName)) return false;
      names.add(p.dbusName);
      return true;
    });
    // playerctld mirrors a real player, including its Identity. Prefer direct
    // sources, but keep the proxy usable if it is the only available service.
    const direct = unique.filter(p => !isProxy(p));
    return direct.length ? direct : unique;
  }
  function select(name) { manualName = name; reconcile(); }
  function reconcile() {
    const manual = players.find(p => p.dbusName === manualName);
    if (manualName && !manual) manualName = "";
    player = manual || (players.indexOf(player) !== -1 && player.isPlaying ? player : null)
      || players.find(p => p.isPlaying) || players[0] || null;
  }
  onPlayersChanged: reconcile()
  Instantiator {
    model: root.players
    delegate: Connections {
      required property var modelData
      target: modelData
      function onIsPlayingChanged() { root.reconcile(); }
    }
  }
  Timer { interval: 1000; repeat: true; running: root.playing; onTriggered: if (root.player) root.player.positionChanged() }
  function previous() { if (canPrevious) player.previous(); }
  function next() { if (canNext) player.next(); }
  function toggle() { if (canToggle) player.togglePlaying(); }
  function seek(seconds) { if (canSeek && isFinite(seconds)) player.position = Math.max(0, Math.min(length, seconds)); }
  function toggleShuffle() { if (canShuffle) player.shuffle = !player.shuffle; }
  function cycleRepeat() {
    if (canRepeat) player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Track
      : player.loopState === MprisLoopState.Track ? MprisLoopState.Playlist : MprisLoopState.None;
  }
}
