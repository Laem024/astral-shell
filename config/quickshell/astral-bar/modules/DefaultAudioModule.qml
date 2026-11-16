import "../components" as Components

Components.StatusNode {
  required property int volume
  required property bool muted
  required property string audioDetail
  kind: "audio"
  label: volume < 0 ? "N/A" : muted ? "MUTE" : volume + "%"
  detail: audioDetail
  accent: tokens.cyan
  level: muted || volume < 0 ? 0 : Math.min(1, volume / 100)
}
