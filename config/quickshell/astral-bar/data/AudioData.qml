pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
  id: root
  readonly property bool available: Pipewire.ready
  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource
  readonly property var nodes: Pipewire.nodes.values.filter(node => !!node.audio)
  // Bind candidates before testing ready: unbound nodes never become ready.
  PwObjectTracker { objects: root.nodes }
  readonly property var outputs: nodes.filter(node => !node.isStream && node.isSink && node.ready)
  readonly property var inputs: nodes.filter(node => !node.isStream && !node.isSink && node.ready)
  // PipeWire playback streams are sinks from the client perspective.
  readonly property var playback: nodes.filter(node => node.isStream && node.isSink && node.ready)

  function usable(node: var): bool {
    return available && !!node && nodes.indexOf(node) !== -1 && node.ready && !!node.audio;
  }
  function percent(node: var): int {
    return usable(node) && Number.isFinite(node.audio.volume) ? Math.round(node.audio.volume * 100) : -1;
  }
  function label(node: var): string {
    return node ? node.description || node.nickname || node.name : "Unavailable";
  }
  function appName(node: var): string {
    return node && node.properties["application.name"] || label(node);
  }
  // Inputs always read as microphones. Sinks borrow the headphones sigil when
  // the device reports a headset form factor, and a display when PipeWire
  // routes audio to HDMI or DisplayPort.
  function glyph(node: var): string {
    if (!node) return "";
    const hints = [node.properties["device.form-factor"], node.properties["device.icon-name"],
      node.name, node.description, node.nickname]
      .filter(value => !!value).join(" ").toLowerCase();
    if (!node.isSink) return "microphone";
    if (/hdmi|displayport|display port/.test(hints)) return "display";
    if (/head(set|phone)|hands-free|hfp/.test(hints)) return "headphones";
    return "speaker";
  }
  function setVolume(node: var, value: real): void {
    if (usable(node) && Number.isFinite(value)) node.audio.volume = Math.max(0, Math.min(1, value));
  }
  function toggleMute(node: var): void {
    if (usable(node)) node.audio.muted = !node.audio.muted;
  }
  function selectOutput(node: var): void {
    if (usable(node) && outputs.indexOf(node) !== -1) Pipewire.preferredDefaultAudioSink = node;
  }
  function selectInput(node: var): void {
    if (usable(node) && inputs.indexOf(node) !== -1) Pipewire.preferredDefaultAudioSource = node;
  }
}
