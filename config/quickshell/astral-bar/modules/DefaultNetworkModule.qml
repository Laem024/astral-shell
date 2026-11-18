import "../components" as Components

Components.StatusNode {
  required property string connectionLabel
  required property string connectionDetail
  property string connectionState: "unavailable"
  required property real strength
  kind: "network"
  label: connectionLabel
  detail: connectionDetail
  networkState: connectionState
  accent: connectionState === "wifi" || connectionState === "ethernet" ? tokens.cyan : tokens.muted
  level: strength
}
