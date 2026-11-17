pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Design
import "../data" as Data

// Keep transport controllers alive while showing one section at a time.
ScrollView {
  id: root
  required property Design.Theme tokens
  readonly property var wifi: Data.NetworkData
  readonly property var bluetooth: Data.BluetoothData
  readonly property var vpn: Data.VpnData
  readonly property bool wifiLive: !!root.wifi.adapter && root.wifi.adapter.state === "connected"
  readonly property var wifiNetwork: root.wifi.networks.find(n => n.active && root.wifi.adapter && n.device === root.wifi.adapter.name) || null
  readonly property var bluetoothDevice: root.bluetooth.devices.find(d => d.connected) || null
  readonly property int bluetoothSaved: root.bluetooth.devices.filter(d => d.paired || d.trusted).length
  readonly property int vpnActive: root.vpn.active.length
  readonly property string wifiValue: root.wifiLive
    ? (root.wifiNetwork ? root.wifiNetwork.ssid : root.wifi.adapter.connection || root.wifi.adapter.name)
    : !root.wifi.available ? "Unavailable"
    : !root.wifi.adapters.length ? "No adapter"
    : !root.wifi.radio ? "Off" : "Disconnected"
  readonly property string wifiDetail: root.wifiLive
    ? (root.wifiNetwork ? root.wifiNetwork.signal + "% · " : "") + (root.wifi.adapter ? root.wifi.adapter.name : "")
    : !root.wifi.available ? (root.wifi.loading ? "Loading…" : "Service off")
    : !root.wifi.adapters.length ? "No adapter"
    : root.wifi.radio ? "Radio on" : "Radio off"
  readonly property string bluetoothValue: !root.bluetooth.available
    ? "Unavailable"
    : !root.bluetooth.powered ? "Off"
    : root.bluetoothDevice ? root.bluetoothDevice.name : "No device"
  readonly property string bluetoothDetail: !root.bluetooth.available
    ? "Service off"
    : root.bluetoothDevice ? "Connected · " + root.bluetoothSaved + " saved"
    : root.bluetoothSaved + (root.bluetoothSaved === 1 ? " saved device" : " saved devices")
  readonly property string vpnValue: root.vpnActive > 0
    ? root.vpn.active[0].name
    : !root.vpn.available ? "Unavailable" : root.vpn.profiles.length ? "Disconnected" : "No profile"
  readonly property string vpnDetail: root.vpnActive > 0
    ? root.vpnActive + (root.vpnActive === 1 ? " tunnel live" : " tunnels live")
    : !root.vpn.available ? (root.vpn.loading ? "Loading…" : "Service off")
    : root.vpn.profiles.length + (root.vpn.profiles.length === 1 ? " saved profile" : " saved profiles")
  contentWidth: availableWidth
  clip: true
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

  property string section: "wifi"
  onSectionChanged: {
    const viewport = root.contentItem as Flickable;
    if (viewport) viewport.contentY = 0;
  }

  ColumnLayout {
    width: root.availableWidth
    spacing: 12
    ConnectionTabs {
      tokens: root.tokens
      current: root.section
      options: [{key: "wifi", label: "Wi-Fi"}, {key: "bluetooth", label: "Bluetooth"}, {key: "vpn", label: "VPN"}]
      onSelected: key => root.section = key
    }
    Text {
      Layout.fillWidth: true
      text: root.section === "wifi" ? root.wifiValue + " · " + root.wifiDetail
        : root.section === "bluetooth" ? root.bluetoothValue + " · " + root.bluetoothDetail
        : root.vpnValue + " · " + root.vpnDetail
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      color: root.tokens.muted
      font { family: root.tokens.font; pixelSize: 11 }
    }
    WifiCard {
      objectName: "connectionWifiCard"
      visible: root.section === "wifi"
      tokens: root.tokens
      onNavigationRequested: {
        const viewport = root.contentItem as Flickable;
        if (viewport) viewport.contentY = 0;
      }
    }
    BluetoothCard {
      objectName: "connectionBluetoothCard"
      visible: root.section === "bluetooth"
      tokens: root.tokens
    }
    VpnCard {
      objectName: "connectionVpnCard"
      visible: root.section === "vpn"
      tokens: root.tokens
    }
  }
}
