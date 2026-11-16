import "../components" as Components

Components.StatusNode {
  required property int count
  kind: "notifications"
  label: String(count).padStart(2, "0")
  detail: count + " unread notifications"
  accent: tokens.lavender
  level: count
}
