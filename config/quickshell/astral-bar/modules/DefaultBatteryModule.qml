import "../components" as Components

Components.StatusNode {
  objectName: "battery"
  required property int percent
  required property bool discharging
  required property string batteryState
  // externalPower is inherited from StatusNode and supplied by the live provider.
  kind: "battery"
  label: percent < 0 ? "N/A" : percent + "%"
  detail: percent < 0 ? "Battery unavailable" : "Battery · " + percent + "% · " + batteryState
    + (externalPower ? " · AC connected" : " · On battery")
  warningEnabled: discharging
  accent: warning ? tokens.alert : tokens.gold
  level: percent / 100
}
