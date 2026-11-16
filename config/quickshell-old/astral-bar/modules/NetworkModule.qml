import "../components" as Components

Components.StatusNode {
  required property string connectionLabel
  required property string connectionDetail
  required property real strength
  kind: "network"
  label: connectionLabel
  detail: connectionDetail
  accent: tokens.cyan
  level: strength
}
