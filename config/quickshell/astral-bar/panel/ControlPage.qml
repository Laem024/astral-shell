pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../common" as Design
import "../data" as Data

// Connections tab: a three-part status rail that jumps to its section, then
// one card per transport.
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

  // Bring a card to the top of the viewport without overscrolling the end.
  function reveal(item) {
    const flickable = root.contentItem as Flickable;
    if (!flickable || !item) return;
    const offset = item.mapToItem(flickable.contentItem, 0, 0).y;
    flickable.contentY = Math.max(0, Math.min(offset - 8, Math.max(0, flickable.contentHeight - flickable.height)));
  }

  component SummaryChip: Button {
    id: chip
    required property string name
    required property string value
    required property string detail
    property color accent: root.tokens.cyan
    property bool live: false
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: 76
    leftPadding: 12; rightPadding: 12; topPadding: 10; bottomPadding: 10
    focusPolicy: Qt.StrongFocus
    Accessible.name: name + ". " + value + ". " + detail + ". Show section"
    contentItem: ColumnLayout {
      spacing: 4
      RowLayout {
        spacing: 6
        Rectangle {
          Layout.preferredWidth: 6
          Layout.preferredHeight: 6
          radius: 3
          color: chip.live ? chip.accent : Qt.alpha(root.tokens.muted, 0.5)
        }
        Text {
          Layout.fillWidth: true
          text: chip.name.toUpperCase()
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: chip.accent
          font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 0.8 }
        }
        Text {
          text: "›"
          textFormat: Text.PlainText
          color: chip.hovered ? chip.accent : root.tokens.muted
          font { family: root.tokens.mono; pixelSize: 13 }
        }
      }
      Text {
        Layout.fillWidth: true
        text: chip.value
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.tokens.text
        font { family: root.tokens.font; pixelSize: 13; weight: Font.Medium }
      }
      Text {
        Layout.fillWidth: true
        text: chip.detail
        textFormat: Text.PlainText
        elide: Text.ElideRight
        color: root.tokens.muted
        font { family: root.tokens.font; pixelSize: 10 }
      }
    }
    background: Rectangle {
      radius: root.tokens.rowRadius
      color: chip.hovered || chip.activeFocus ? Qt.alpha(chip.accent, 0.08) : root.tokens.raised
      border.width: chip.activeFocus ? 2 : 1
      border.color: chip.activeFocus ? root.tokens.cyan
        : chip.live ? Qt.alpha(chip.accent, 0.35) : root.tokens.border
    }
  }

  ColumnLayout {
    width: root.availableWidth
    spacing: 12
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      SummaryChip {
        name: "Wi-Fi"
        value: root.wifiValue
        detail: root.wifiDetail
        accent: root.tokens.cyan
        live: root.wifiLive
        onClicked: root.reveal(wifiCard)
      }
      SummaryChip {
        name: "Bluetooth"
        value: root.bluetoothValue
        detail: root.bluetoothDetail
        accent: root.tokens.lavender
        live: !!root.bluetoothDevice
        onClicked: root.reveal(bluetoothCard)
      }
      SummaryChip {
        name: "VPN"
        value: root.vpnValue
        detail: root.vpnDetail
        accent: root.tokens.gold
        live: root.vpnActive > 0
        onClicked: root.reveal(vpnCard)
      }
    }
    WifiCard {
      id: wifiCard
      objectName: "connectionWifiCard"
      tokens: root.tokens
      onNavigationRequested: root.reveal(wifiCard)
    }
    BluetoothCard {
      id: bluetoothCard
      objectName: "connectionBluetoothCard"
      tokens: root.tokens
    }
    VpnCard {
      id: vpnCard
      objectName: "connectionVpnCard"
      tokens: root.tokens
    }
  }
}
