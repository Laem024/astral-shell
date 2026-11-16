pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../data" as Data

PanelCard {
  id: root
  title: ""
  radius: 12
  contentSpacing: 14
  readonly property color accent: root.tokens.lavender
  readonly property var service: Data.BluetoothData
  property string section: "saved"
  property string forgetAddress: ""
  readonly property var savedDevices: service.devices.filter(d => d.paired || d.trusted || d.connected)
  readonly property var nearbyDevices: service.devices.filter(d => !d.paired && !d.trusted && !d.connected)
  readonly property var visibleDevices: (section === "saved" ? savedDevices : nearbyDevices).slice().sort((a, b) => Number(b.connected) - Number(a.connected) || a.name.localeCompare(b.name))
  readonly property var forgottenDevice: service.devices.find(d => d.address === forgetAddress) || null
  readonly property var pendingDevice: service.devices.find(d => d.address === service.target) || null
  readonly property bool focusedView: service.busy || forgetAddress !== ""
  Component.onCompleted: service.viewers++
  Component.onDestruction: service.viewers--

  component Label: Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    color: root.tokens.text
    font { family: root.tokens.font; pixelSize: 12 }
  }
  component Caption: Label { color: root.tokens.muted; font.pixelSize: 10 }
  component Eyebrow: Caption {
    color: root.accent
    font { family: root.tokens.mono; pixelSize: 9; letterSpacing: 1.2 }
  }
  component Action: PanelButton {
    id: action
    tokens: root.tokens
    property color tint: root.accent
    readonly property color accent: action.destructive ? root.tokens.alert : action.tint
    property string symbol: ""
    property bool quiet: false
    Layout.minimumWidth: 0
    implicitHeight: 34
    opacity: enabled ? 1 : 0.4
    contentItem: RowLayout {
      spacing: 6
      Text {
        visible: action.symbol !== ""
        text: action.symbol
        color: action.accent
        font { family: root.tokens.mono; pixelSize: 13 }
      }
      Text {
        Layout.fillWidth: true
        text: action.text
        textFormat: Text.PlainText
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
        color: action.destructive || action.selected ? action.accent : root.tokens.text
        font { family: root.tokens.font; pixelSize: 11; weight: Font.Medium }
      }
    }
    background: Rectangle {
      radius: 7
      color: action.quiet
        ? (action.down || action.hovered || action.activeFocus ? Qt.alpha(action.accent, 0.07) : "transparent")
        : Qt.alpha(action.accent, action.down ? 0.16 : action.selected ? 0.1 : action.hovered ? 0.06 : 0.025)
      border.color: action.activeFocus ? root.tokens.gold
        : action.quiet ? "transparent"
        : Qt.alpha(action.accent, action.selected ? 0.38 : action.hovered ? 0.26 : 0.12)
    }
  }
  component DeviceTile: Rectangle {
    id: tile
    required property var device
    readonly property bool live: tile.device.connected
    readonly property bool saved: tile.device.paired || tile.device.trusted
    Layout.fillWidth: true
    implicitHeight: tileBody.implicitHeight + 24
    radius: 10
    color: tile.live ? Qt.alpha(root.accent, 0.07) : Qt.alpha(root.tokens.surface, 0.5)
    border.color: tile.live ? Qt.alpha(root.accent, 0.3) : root.tokens.border
    ColumnLayout {
      id: tileBody
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
      spacing: 10
      RowLayout {
        Layout.fillWidth: true
        spacing: 10
        ConnectionMark {
          kind: "bluetooth"
          tokens: root.tokens
          accent: root.accent
          active: tile.live
          implicitWidth: 34
          implicitHeight: 34
        }
        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: 2
          Text {
            Layout.fillWidth: true
            text: tile.device.name
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: tile.live ? root.accent : root.tokens.text
            font { family: root.tokens.font; pixelSize: 13; weight: Font.Medium }
          }
          Caption {
            text: tile.device.address
            font { family: root.tokens.mono; pixelSize: 9 }
          }
        }
        StatusPill {
          tokens: root.tokens
          text: tile.live ? "LIVE" : tile.saved ? "SAVED" : "NEW"
          accent: tile.live ? root.accent : root.tokens.muted
        }
      }
      GridLayout {
        Layout.fillWidth: true
        columns: tile.width < 250 ? 1 : 2
        columnSpacing: 8
        rowSpacing: 6
        Action {
          Layout.fillWidth: true
          selected: !tile.live
          text: tile.live ? "Disconnect" : tile.saved ? "Reconnect" : "Pair"
          symbol: tile.live ? "" : "+"
          enabled: root.service.powered && !root.service.busy
          Accessible.name: text + " " + tile.device.name
          onClicked: tile.live ? root.service.disconnectDevice(tile.device.address) : root.service.connectDevice(tile.device.address)
        }
        Action {
          Layout.fillWidth: tile.width < 250
          text: "Forget"
          destructive: true
          quiet: true
          visible: tile.saved
          enabled: !root.service.busy
          Accessible.name: "Forget " + tile.device.name
          onClicked: root.forgetAddress = tile.device.address
        }
      }
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 12
    ConnectionMark {
      kind: "bluetooth"
      tokens: root.tokens
      accent: root.accent
      active: root.service.powered
    }
    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: 2
      Eyebrow { text: "DEVICES" }
      Text {
        Layout.fillWidth: true
        text: "Bluetooth"
        textFormat: Text.PlainText
        color: root.tokens.text
        font { family: root.tokens.font; pixelSize: 19; weight: Font.Medium }
      }
      Caption { text: root.service.state }
    }
    PanelSwitch {
      tokens: root.tokens
      accent: root.accent
      checked: root.service.powered
      enabled: root.service.available && root.service.selected !== "" && !root.service.busy
      opacity: enabled ? 1 : 0.45
      Accessible.name: "Bluetooth power"
      onClicked: root.service.setPower(checked)
    }
  }
  ComboBox {
    id: adapterChoice
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    visible: root.service.adapters.length > 1
    enabled: !root.service.busy && !root.forgetAddress
    model: root.service.adapters.map(a => a.name + " · " + a.address)
    currentIndex: root.service.adapters.findIndex(a => a.address === root.service.selected)
    Accessible.name: "Bluetooth adapter"
    font { family: root.tokens.font; pixelSize: 11 }
    leftPadding: 11
    rightPadding: 30
    contentItem: Text {
      text: adapterChoice.displayText
      textFormat: Text.PlainText
      font: adapterChoice.font
      color: root.tokens.text
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
    indicator: Text {
      x: adapterChoice.width - width - 11
      anchors.verticalCenter: parent.verticalCenter
      text: adapterChoice.popup.visible ? "−" : "+"
      color: root.accent
      font { family: root.tokens.mono; pixelSize: 14 }
    }
    background: Rectangle {
      radius: 7
      color: adapterChoice.hovered || adapterChoice.popup.visible ? Qt.alpha(root.accent, 0.06) : Qt.alpha(root.tokens.surface, 0.7)
      border.color: adapterChoice.activeFocus ? root.accent : root.tokens.border
    }
    popup: Popup {
      y: adapterChoice.height + 4
      width: adapterChoice.width
      padding: 4
      implicitHeight: Math.min(200, adapterList.contentHeight + 8)
      contentItem: ListView {
        id: adapterList
        clip: true
        implicitHeight: contentHeight
        model: adapterChoice.popup.visible ? adapterChoice.delegateModel : null
        currentIndex: adapterChoice.highlightedIndex
        ScrollIndicator.vertical: ScrollIndicator {}
      }
      background: Rectangle {
        radius: 8
        color: root.tokens.surface
        border.color: Qt.alpha(root.accent, 0.24)
      }
    }
    delegate: ItemDelegate {
      id: adapterOption
      required property int index
      required property string modelData
      width: adapterChoice.width - 2
      implicitHeight: 36
      highlighted: adapterChoice.highlightedIndex === index
      contentItem: Text {
        text: adapterOption.modelData
        color: adapterOption.index === adapterChoice.currentIndex ? root.accent : root.tokens.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        font { family: root.tokens.font; pixelSize: 11 }
      }
      background: Rectangle {
        radius: 6
        color: adapterOption.highlighted ? Qt.alpha(root.accent, 0.1) : "transparent"
      }
    }
    onActivated: root.service.selectAdapter(root.service.adapters[currentIndex].address)
  }
  Caption {
    visible: root.service.adapters.length === 1
    text: "ADAPTER  /  " + (root.service.adapters[0] || {}).name
    font { family: root.tokens.mono; pixelSize: 9 }
  }
  Rectangle {
    Layout.fillWidth: true
    visible: root.service.error !== ""
    implicitHeight: errorText.implicitHeight + 24
    radius: 8
    color: Qt.alpha(root.tokens.alert, 0.07)
    border.color: Qt.alpha(root.tokens.alert, 0.3)
    Label {
      id: errorText
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
      text: root.service.error
      color: root.tokens.alert
      font.pixelSize: 11
    }
  }

  // Keep pairing prompts and destructive confirmation separate from device actions.
  ColumnLayout {
    Layout.fillWidth: true
    visible: root.focusedView
    spacing: 10
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
    Eyebrow {
      text: root.forgetAddress ? "REMOVE PAIRING" : "DEVICE CONNECTION"
      color: root.forgetAddress ? root.tokens.alert : root.accent
    }
    Label {
      text: root.forgetAddress ? (root.forgottenDevice ? root.forgottenDevice.name : root.forgetAddress) : root.pendingDevice ? root.pendingDevice.name : "Bluetooth"
      font { pixelSize: 16; weight: Font.Medium }
    }
    Caption {
      visible: root.forgetAddress !== ""
      text: root.forgottenDevice && root.forgottenDevice.connected
        ? "This device is connected. Forgetting it will end the connection and remove pairing."
        : "Remove this saved device? You will need to pair it again to reconnect."
    }
    Label {
      visible: root.service.busy
      text: root.service.prompt || root.service.pending
      color: root.service.promptKind ? root.accent : root.tokens.text
    }
    TextField {
      id: pin
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      visible: ["pin", "passkey"].includes(root.service.promptKind)
      implicitHeight: 40
      leftPadding: 12; rightPadding: 12
      echoMode: TextInput.Password
      inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
      placeholderText: root.service.promptKind === "passkey" ? "Enter passkey" : "Enter PIN"
      Accessible.name: placeholderText
      color: root.tokens.text
      placeholderTextColor: root.tokens.muted
      selectionColor: root.accent
      selectedTextColor: root.tokens.background
      font { family: root.tokens.font; pixelSize: 12 }
      background: Rectangle {
        radius: 7
        color: Qt.alpha(root.tokens.surface, 0.7)
        border.color: pin.activeFocus ? root.accent : root.tokens.border
      }
      onAccepted: { root.service.answer(text); clear(); }
      onVisibleChanged: { clear(); if (visible) forceActiveFocus(); }
    }
    GridLayout {
      Layout.fillWidth: true
      columns: root.width < 280 ? 1 : 3
      columnSpacing: 8
      rowSpacing: 6
      Action {
        Layout.fillWidth: true
        visible: root.forgetAddress !== ""
        text: "Forget device"; destructive: true
        enabled: !root.service.busy
        onClicked: { root.service.forget(root.forgetAddress); root.forgetAddress = ""; }
      }
      Action {
        Layout.fillWidth: true
        visible: pin.visible || root.service.promptKind === "confirm"
        text: pin.visible ? "Submit" : "Accept"
        selected: true
        onClicked: { root.service.answer(pin.visible ? pin.text : "yes"); pin.clear(); }
      }
      Action {
        visible: root.service.promptKind === "confirm"
        Layout.fillWidth: root.width < 280
        text: "Reject"
        tint: root.tokens.muted
        onClicked: root.service.answer("no")
      }
      Action {
        Layout.fillWidth: root.width < 280
        text: "Cancel"
        tint: root.tokens.muted
        onClicked: { pin.clear(); if (root.forgetAddress) root.forgetAddress = ""; else root.service.cancel(); }
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: !root.focusedView
    spacing: 8
    ConnectionTabs {
      tokens: root.tokens
      accent: root.accent
      current: root.section
      options: [
        {key: "saved", label: "Saved · " + root.savedDevices.length},
        {key: "nearby", label: "Nearby · " + root.nearbyDevices.length}
      ]
      onSelected: key => root.section = key
    }
    Action {
      Layout.fillWidth: true
      text: root.service.scanning ? "Stop scanning" : "Scan for devices"
      symbol: "↻"
      enabled: root.service.powered && !root.service.busy
      selected: root.service.scanning
      onClicked: {
        if (root.service.scanning) root.service.stopScan();
        else { root.section = "nearby"; root.service.scan(); }
      }
    }
    Caption {
      visible: root.section === "nearby" && root.service.powered
      text: root.service.scanning ? "Searching nearby… Keep your device in pairing mode." : "Put your device in pairing mode, then scan to find it."
    }
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 8
      Repeater {
        model: root.visibleDevices
        DeviceTile { required property var modelData; device: modelData }
      }
    }
    EmptyState {
      visible: root.visibleDevices.length === 0
      tokens: root.tokens
      accent: root.accent
      mark: root.section === "saved" ? "bluetooth" : "search"
      title: !root.service.powered ? "Bluetooth is unavailable"
        : root.section === "saved" ? "Your devices, one tap away"
        : root.service.scanning ? "Looking for devices…"
        : "Find a nearby device"
      message: !root.service.available ? "Check that the Bluetooth service is running."
        : !root.service.adapters.length ? "Connect a Bluetooth adapter to get started."
        : !root.service.powered ? "Turn on Bluetooth to connect your devices."
        : root.section === "saved" ? "Devices you pair will appear here for quick reconnection."
        : "Discovered devices will appear here."
    }
  }
  Keys.onEscapePressed: event => {
    if (root.forgetAddress) root.forgetAddress = "";
    else if (root.service.busy) root.service.cancel();
    else event.accepted = false;
  }
}
