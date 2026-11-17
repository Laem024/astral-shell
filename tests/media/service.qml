import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Services.Mpris
import "../../config/quickshell/astral-bar/data" as Data
import "../../config/quickshell/astral-bar/panel" as Panel
import "../../config/quickshell/astral-bar/modules" as Modules
import "../../config/quickshell/astral-bar/settings" as Settings
import "../../config/quickshell/common" as Design

Scope {
  id: root
  property int stage: 0
  property int ticks: 0
  property int positionTicks: 0
  property bool screenshotDone: false
  readonly property string testArtwork: "data:image/svg+xml;utf8," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" width="240" height="320"><defs><linearGradient id="sky" x2="1" y2="1"><stop stop-color="#243c4c"/><stop offset="1" stop-color="#91b4a0"/></linearGradient></defs><rect width="240" height="320" fill="url(#sky)"/><circle cx="170" cy="110" r="62" fill="#e4b882"/><path d="M0 250L100 130L240 260V320H0Z" fill="#243c3d"/><path d="M0 290L170 200L240 270V320H0Z" fill="#152a30"/></svg>')
  component Player: QtObject {
    property string dbusName: "org.mpris.MediaPlayer2.test"
    property string identity: "Test player"
    property bool isPlaying: false
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string trackArtUrl: "file:///nonexistent-astral-test-cover"
    property var metadata: ({"mpris:trackid": "/track/one"})
    property real position: 20
    property real length: 120
    property bool lengthSupported: true
    property bool positionSupported: true
    property bool canControl: true
    property bool canGoPrevious: true
    property bool canGoNext: true
    property bool canTogglePlaying: true
    property bool canSeek: true
    property bool shuffleSupported: true
    property bool shuffle: false
    property bool loopSupported: true
    property int loopState: MprisLoopState.None
    property int previousCalls: 0
    property int nextCalls: 0
    property int toggleCalls: 0
    function previous() { previousCalls++; }
    function next() { nextCalls++; }
    function togglePlaying() { toggleCalls++; }
  }
  Player { id: first }
  Player { id: second; dbusName: "org.mpris.MediaPlayer2.second" }
  Player { id: special; dbusName: "org.mpris.MediaPlayer2.late" }
  Player { id: proxy; dbusName: "org.mpris.MediaPlayer2.playerctld" }
  Data.MediaService { id: media; rawPlayers: [first, second, special] }
  QtObject { id: settings; property var value: Settings.SettingsData.value }
  Design.Theme { id: theme; settings: settings }
  Window {
    id: scene
    color: theme.background
    visible: true; width: 1400; height: 650
  Panel.MediaPage { id: page; tokens: theme; media: media; width: 300; height: 520 }
  Panel.MediaPage { id: small; tokens: theme; media: media; x: 320; width: 240; height: 300 }
  Panel.MediaPage { id: fitted; tokens: theme; media: media; x: 1000; width: 382; height: 465 }
  Modules.MusicModule { y: 540; tokens: theme; media: media; width: implicitWidth; height: implicitHeight }
  Modules.MusicModule { tokens: theme; media: media; x: 320; y: 320; compact: true; width: implicitWidth; height: implicitHeight }
  Modules.MusicModule { id: vertical; tokens: theme; media: media; x: 600; vertical: true; width: implicitWidth; height: implicitHeight }
  }
  function find(item, name) {
    if (item.objectName === name) return item;
    for (const child of item.children || []) {
      const found = find(child, name);
      if (found) return found;
    }
    return null;
  }
  function check(condition, message) { if (!condition) throw new Error(message); }
  function logic() {
    media.rawPlayers = [proxy, first, first, second];
    check(media.players.length === 2 && media.players.indexOf(proxy) === -1, "proxy and repeated service removed");
    check(media.playerOptions.length === 2 && media.playerOptions[0].name !== media.playerOptions[1].name, "independent instances distinguished");
    media.select(first.dbusName);
    media.rawPlayers = [proxy, first, second, first];
    check(media.player === first && !media.automatic, "manual selection survives discovery updates");
    media.rawPlayers = [proxy];
    check(media.players.length === 1 && media.player === proxy && media.automatic, "proxy fallback after direct players disappear");
    media.select(proxy.dbusName);
    media.rawPlayers = [proxy, first];
    check(media.player === first && media.automatic && media.players.length === 1, "direct source replaces proxy");
    media.rawPlayers = [first, second, special];
    check(Data.MediaData.automatic && Data.MediaData !== media, "registered production singleton");
    check(media.player === first, "initial selection");
    second.isPlaying = true;
    check(media.player === second, "automatic priority");
    first.isPlaying = true;
    check(media.player === second, "retain playing player");
    media.select(first.dbusName);
    first.isPlaying = false;
    check(media.player === first && !media.automatic, "manual retention");
    media.select("");
    check(media.player === second, "return to automatic");
    media.rawPlayers = [first, special];
    check(media.player === first, "disconnect automatic");
    media.select(special.dbusName);
    media.rawPlayers = [first, second];
    check(media.automatic && media.player === second, "disconnect manual");
    media.select(first.dbusName);
    media.previous(); media.next(); media.toggle(); media.seek(500);
    check(first.previousCalls === 1 && first.nextCalls === 1 && first.toggleCalls === 1 && first.position === 120, "transport controls / seek clamp");
    media.toggleShuffle(); media.cycleRepeat();
    check(first.shuffle && media.repeatMode === "Track", "shuffle and track repeat");
    media.cycleRepeat(); check(media.repeatMode === "Playlist", "playlist repeat");
    media.cycleRepeat(); check(media.repeatMode === "Off", "repeat off");
    first.canControl = false;
    media.previous(); media.next(); media.toggle(); media.seek(0); media.toggleShuffle(); media.cycleRepeat();
    check(first.previousCalls === 1 && first.nextCalls === 1 && first.toggleCalls === 1 && first.position === 120 && first.shuffle && media.repeatMode === "Off", "restricted controls");
    first.canControl = true; first.canSeek = false; media.seek(0);
    check(first.position === 120 && !media.canSeek, "seek capability");
    first.canSeek = true; first.lengthSupported = false;
    check(media.length === 0 && media.progress === 0 && !media.canSeek && media.position === 120, "unknown duration");
    first.lengthSupported = true;
    check(media.title === "Unknown title" && media.artist === "Unknown artist", "missing metadata");
    check(vertical.implicitHeight > vertical.implicitWidth, "vertical controls geometry");
    media.rawPlayers = [];
    check(!media.player && !media.canToggle && media.title === "Nothing playing", "empty state");
    media.rawPlayers = [first, second, special]; media.select(first.dbusName);
  }
  Component.onCompleted: Qt.callLater(() => {
    try { logic(); } catch (error) { console.log("MEDIA_FAIL", error); Qt.quit(); }
  })
  Connections {
    target: first
    function onPositionChanged() { root.positionTicks++; }
  }
  Timer {
    interval: 80; running: true; repeat: true
    onTriggered: {
      try {
        root.ticks++;
        if (root.ticks > 60) throw new Error("test timeout at stage " + root.stage);
        const artwork = root.find(page, "mediaArtwork");
        const fallback = root.find(page, "mediaArtworkFallback");
        if (root.stage === 0) {
          root.check(!root.find(page, "mediaQueueToggle") && !root.find(page, "mediaQueueUnavailable"), "queue UI removed");
          root.check(media.pageVisible === undefined && media.transport === undefined, "no queue polling or process transport");
          const play = root.find(page, "mediaTransport-play");
          const slider = root.find(page, "mediaSeek");
          root.check(play && play.enabled && play.width > 0 && slider.height >= 24, "usable transport and slider");
          const calls = first.toggleCalls;
          play.clicked(); root.check(first.toggleCalls === calls + 1, "Music button dispatch");
          first.canControl = false; play.clicked();
          root.check(!play.enabled && first.toggleCalls === calls + 1, "disabled Music button");
          first.canControl = true;
          root.find(page, "mediaPlayerSelector").popup.open();
          first.trackArtUrl = root.testArtwork;
          root.stage++;
        } else if (root.stage === 1 && artwork.status === Image.Ready) {
          const selector = root.find(page, "mediaPlayerSelector");
          root.check(selector.popup.visible && selector.popup.contentItem.count > 0, "player selector remains usable inside rounded viewport");
          selector.popup.close();
          root.check(!fallback.visible && artwork.fillMode === Image.PreserveAspectFit, "artwork replaces fallback without cropping");
          root.check(Math.abs(artwork.paintedWidth - artwork.width) <= 1 && Math.abs(artwork.paintedHeight - artwork.height) <= 1, "portrait artwork fits its frame without side bars");
          root.check(artwork.sourceSize.width >= artwork.width * 2, "artwork resolution");
          const frame = root.find(page, "mediaArtworkFrame");
          root.check(frame.height >= 150 && Math.abs(frame.width / frame.height - 0.75) < 0.01, "artwork frame follows portrait proportions");
          first.trackArtUrl = "file:///nonexistent-astral-test-cover";
          root.stage++;
        } else if (root.stage === 2 && artwork.status === Image.Error) {
          root.check(fallback.visible, "invalid artwork fallback");
          first.trackArtUrl = root.testArtwork;
          first.trackTitle = "Stellar Drift";
          first.trackArtist = "Aether Archives";
          first.trackAlbum = "Observatory";
          first.position = 42;
          first.isPlaying = true;
          root.positionTicks = 0;
          root.stage++;
        } else if (root.stage === 3 && artwork.status === Image.Ready) {
          for (const view of [page, small, fitted]) {
            const viewport = root.find(view, "mediaViewport");
            root.check(viewport.contentHeight <= view.height, "player has unnecessary scrolling at " + view.width + "x" + view.height);
          }
          const footer = root.find(page, "mediaRepeatMode");
          const footerBottom = footer.mapToItem(page, 0, footer.height).y;
          root.check(footerBottom >= page.height - 24 && footerBottom <= page.height - 12, "player fills panel without a vacant footer");
          const smallArtwork = root.find(small, "mediaArtwork");
          root.check(smallArtwork.source.toString() === artwork.source.toString(), "shared artwork across pages");
          const screenshot = Quickshell.env("ASTRAL_MEDIA_SCREENSHOT");
          if (screenshot) scene.contentItem.grabToImage(result => { result.saveToFile(screenshot); root.screenshotDone = true; });
          else root.screenshotDone = true;
          root.stage++;
        } else if (root.stage === 4 && root.screenshotDone && root.positionTicks > 0) {
          first.trackTitle = "A long track title that wraps onto a second line";
          first.trackArtist = "An artist name that also needs a second line";
          fitted.height = 400;
          root.stage++;
        } else if (root.stage === 5) {
          const viewport = root.find(fitted, "mediaViewport");
          // Long metadata may scroll in short panels instead of squeezing the artwork.
          const footer = root.find(fitted, "mediaRepeatMode");
          root.check(footer.mapToItem(viewport.contentItem, 0, footer.height).y <= viewport.contentHeight - fitted.inset + 1, "short panel reserves space below the footer");
          const frame = root.find(fitted, "mediaArtworkFrame");
          const center = frame.mapToItem(fitted, frame.width / 2, frame.height / 2);
          root.check(Math.abs(center.x - fitted.width / 2) <= 1, "artwork stays centered in a 400px-high Music panel");
          const selector = root.find(fitted, "mediaPlayerSelector");
          root.check(frame.mapToItem(fitted, 0, 0).y - selector.mapToItem(fitted, 0, selector.height).y >= 20, "artwork clears the player selector");
          const slider = root.find(fitted, "mediaSeek");
          root.check(slider.mapToItem(fitted, 0, 0).y - frame.mapToItem(fitted, 0, frame.height).y >= 20, "artwork clears the timeline");
          console.log("MEDIA_PASS"); Qt.quit();
        }
      } catch (error) { console.log("MEDIA_FAIL", error); Qt.quit(); }
    }
  }
}
