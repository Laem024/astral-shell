pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Singleton {
  id: root

  readonly property bool networkAvailable: NetworkData.available
  readonly property var networkDevice: NetworkData.connectedDevice
  readonly property bool ethernet: !!networkDevice && networkDevice.type === "ethernet"
  readonly property string networkLabel: !networkAvailable ? "N/A" : !networkDevice ? "OFF" : ethernet ? "ETH" : "WiFi"
  readonly property real networkLevel: !networkDevice ? 0 : ethernet ? 1 : NetworkData.strength
  readonly property var activeNetwork: NetworkData.networks.find(n => n.active && networkDevice && n.device === networkDevice.name) || null
  readonly property string networkDetail: !networkAvailable ? "Network unavailable" : !networkDevice ? "Disconnected"
    : (ethernet ? "Ethernet" : "Wi-Fi") + " · " + (!ethernet && activeNetwork ? activeNetwork.ssid : networkDevice.connection) + " · " + networkDevice.name
      + (ethernet ? "" : " · " + Math.round(networkLevel * 100) + "%")

  readonly property PwNode sink: AudioData.sink
  readonly property bool audioAvailable: AudioData.usable(sink)
  readonly property int volume: AudioData.percent(sink)
  readonly property bool muted: audioAvailable && sink.audio.muted
  readonly property string audioDetail: volume < 0 ? "Audio unavailable"
    : (muted ? "Muted · " : "Volume · ") + volume + "% · " + AudioData.label(sink)

  readonly property UPowerDevice battery: UPower.displayDevice
  readonly property bool batteryAvailable: !!battery && !!battery.ready && battery.isLaptopBattery && battery.isPresent
    && Number.isFinite(battery.percentage) && battery.percentage >= 0 && battery.percentage <= 1
  readonly property int batteryPercent: batteryAvailable ? Math.round(battery.percentage * 100) : -1
  readonly property bool externalPower: batteryAvailable && !UPower.onBattery
  readonly property bool discharging: batteryAvailable && battery.state === UPowerDeviceState.Discharging
  readonly property string batteryState: !batteryAvailable ? "Unavailable" : UPowerDeviceState.toString(battery.state)
}
