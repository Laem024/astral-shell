pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../data" as Data

PanelCard {
  id: root
  title: ""
  contentSpacing: 14
  signal navigationRequested()
  readonly property color accent: root.tokens.cyan
  property string section: "available"
  readonly property var visibleNetworks: service.radio ? service.networks.filter(n => n.device === service.selected) : []
  readonly property var currentNetwork: visibleNetworks.find(n => n.active) || null
  readonly property bool connected: !!service.adapter && service.adapter.state === "connected"
  readonly property bool canConnect: service.radio && !!service.adapter && !service.busy
  readonly property bool personalPassword: security !== "open" && security !== "--"
    && (!choices.length || ["wpa-psk", "sae"].includes((choices[profile.currentIndex] || {}).security))
  readonly property bool canSubmit: canConnect && (!hiddenNetwork || ssid.text !== "")
    && (choices.length > 0 || security === "open" || password.text !== "")
  readonly property int nearbyCount: root.visibleNetworks.filter(n => !n.active).length
  property bool form: false
  property bool hiddenNetwork: false
  property string targetSsid: ""
  property string security: "open"
  property var choices: []
  property string forgetUuid: ""
  property string forgetName: ""
  readonly property var service: Data.NetworkData
  function reset() {
    password.text = "";
    reveal.checked = false;
    ssid.text = "";
    form = false;
    choices = [];
    forgetUuid = "";
  }
  function choose(network) {
    reset();
    targetSsid = network.ssid;
    hiddenNetwork = false;
    security = network.security === "--" ? "open" : /WPA3/.test(network.security) && !/WPA2/.test(network.security) ? "sae" : "wpa-psk";
    choices = service.compatible(network);
    if (!choices.length && /802.1X|EAP|WEP|OWE/.test(network.security)) {
      service.error = "This network requires an existing compatible profile. Create it outside this panel.";
      return;
    }
    if (/802.1X|EAP|WEP|OWE/.test(network.security)) security = network.security;
    form = true;
    profile.currentIndex = 0;
    if (personalPassword) password.forceActiveFocus();
    else connectButton.forceActiveFocus();
  }
  function hiddenProfiles() {
    if (!hiddenNetwork) return;
    choices = service.compatible({ssid:ssid.text, security:security === "open" ? "--" : security === "sae" ? "WPA3" : "WPA2"});
    profile.currentIndex = 0;
  }
  function submit() {
    if (!form || !canSubmit) return;
    if (choices.length) service.activate(choices[profile.currentIndex].uuid, password.text, hiddenNetwork);
    else service.connectNew(hiddenNetwork ? ssid.text : targetSsid, security, password.text, hiddenNetwork);
    reset();
  }
  Component.onCompleted: { service.viewers++; service.refresh(); }
  Component.onDestruction: { service.viewers--; }
  onVisibleChanged: if (!visible) reset()
  onFormChanged: if (form) navigationRequested()
  onForgetUuidChanged: if (forgetUuid !== "") navigationRequested()
  Keys.onEscapePressed: event => {
    if (form || forgetUuid !== "") reset();
    else event.accepted = false;
  }

  function securityLabel(value) {
    if (!value || value === "--" || value === "open") return "Open network";
    if (/eap|ieee8021x/.test(value)) return "Enterprise network";
    if (value === "owe") return "Enhanced open network";
    if (value === "sae") return "WPA3 Personal";
    if (value === "wpa-psk") return "WPA/WPA2 Personal";
    return value;
  }
  function openSaved(saved) {
    reset();
    targetSsid = saved.ssid || saved.name;
    security = saved.security || "open";
    choices = [saved];
    hiddenNetwork = false;
    form = true;
    profile.currentIndex = 0;
    connectButton.forceActiveFocus();
  }

  component Label: Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    color: root.tokens.text
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    font { family: root.tokens.font; pixelSize: 13 }
  }
  component Caption: Label {
    color: root.tokens.muted
    font.pixelSize: 11
  }
  component Eyebrow: Caption {
    color: root.accent
    font { family: root.tokens.mono; pixelSize: 10; letterSpacing: 1 }
  }
  component SignalMeter: Item {
    id: meter
    property real strength: 0
    property bool highlighted: false
    implicitWidth: 25
    implicitHeight: 17
    Row {
      anchors.centerIn: parent
      width: 25
      height: 17
      spacing: 2.5
      Repeater {
        model: [4, 7, 10, 13, 16]
        Rectangle {
          required property int index
          required property int modelData
          width: 3
          height: modelData
          y: 17 - height
          radius: 1.5
          color: meter.strength > index * 20
            ? (meter.highlighted ? root.accent : root.tokens.text)
            : Qt.alpha(root.tokens.muted, 0.22)
        }
      }
    }
  }
  component NetworkMark: Rectangle {
    id: mark
    property int strength: -1
    property bool active: false
    implicitWidth: 34
    implicitHeight: 34
    radius: root.tokens.rowRadius
    color: mark.active ? Qt.alpha(root.accent, 0.12) : root.tokens.sunken
    border.color: mark.active ? Qt.alpha(root.accent, 0.35) : root.tokens.hairline
    SignalMeter {
      anchors.centerIn: parent
      strength: mark.strength
      highlighted: mark.active
    }
  }
  component Action: PanelButton {
    tokens: root.tokens
    tint: root.accent
    Layout.minimumWidth: 0
  }
  component Field: TextField {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: 40
    leftPadding: 12; rightPadding: 12
    color: root.tokens.text
    placeholderTextColor: root.tokens.muted
    selectionColor: root.accent
    selectedTextColor: root.tokens.background
    font { family: root.tokens.font; pixelSize: 13 }
    background: Rectangle {
      radius: root.tokens.rowRadius
      color: root.tokens.background
      border.width: parent.activeFocus ? 2 : 1
      border.color: parent.activeFocus ? root.tokens.cyan : root.tokens.border
    }
  }
  component Choice: ComboBox {
    id: choice
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: 40
    leftPadding: 12
    rightPadding: 34
    font { family: root.tokens.font; pixelSize: 13 }
    contentItem: Text {
      text: choice.displayText
      textFormat: Text.PlainText
      font: choice.font
      color: choice.enabled ? root.tokens.text : root.tokens.muted
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
    indicator: Text {
      x: choice.width - width - 12
      anchors.verticalCenter: parent.verticalCenter
      text: choice.popup.visible ? "−" : "+"
      color: root.accent
      font { family: root.tokens.mono; pixelSize: 14 }
    }
    background: Rectangle {
      radius: root.tokens.rowRadius
      color: root.tokens.background
      border.width: choice.activeFocus ? 2 : 1
      border.color: choice.activeFocus ? root.tokens.cyan : root.tokens.border
    }
    delegate: ItemDelegate {
      id: option
      required property int index
      required property string modelData
      width: choice.width - 2
      implicitHeight: 38
      highlighted: choice.highlightedIndex === index
      Accessible.name: option.modelData
      contentItem: Text {
        text: option.modelData
        textFormat: Text.PlainText
        color: option.index === choice.currentIndex ? root.accent : root.tokens.text
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
        font { family: root.tokens.font; pixelSize: 13 }
      }
      background: Rectangle {
        radius: root.tokens.rowRadius - 2
        color: option.highlighted ? Qt.alpha(root.accent, 0.12) : "transparent"
      }
    }
    popup: Popup {
      y: choice.height + 4
      width: choice.width
      padding: 4
      implicitHeight: Math.min(224, choiceList.contentHeight + 8)
      contentItem: ListView {
        id: choiceList
        clip: true
        implicitHeight: contentHeight
        model: choice.popup.visible ? choice.delegateModel : null
        currentIndex: choice.highlightedIndex
        ScrollIndicator.vertical: ScrollIndicator {}
      }
      background: Rectangle {
        radius: root.tokens.rowRadius
        color: root.tokens.surface
        border.color: root.tokens.border
      }
    }
  }
  component NetworkRow: Button {
    id: networkRow
    required property string name
    property string detail: ""
    property int strength: -1
    property bool active: false
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: 60
    leftPadding: 10; rightPadding: 10; topPadding: 8; bottomPadding: 8
    opacity: enabled ? 1 : 0.45
    Accessible.name: name + ". " + detail
    contentItem: RowLayout {
      spacing: 10
      NetworkMark {
        strength: networkRow.strength
        active: networkRow.active
      }
      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2
        Text {
          Layout.fillWidth: true
          text: networkRow.name
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: networkRow.active ? root.accent : root.tokens.text
          font { family: root.tokens.font; pixelSize: 13; weight: Font.Medium }
        }
        Caption { text: networkRow.detail }
      }
      StatusPill {
        visible: networkRow.active
        tokens: root.tokens
        text: "LIVE"
        accent: root.accent
      }
      Text {
        visible: !networkRow.active
        text: "›"
        color: root.tokens.muted
        font { family: root.tokens.mono; pixelSize: 17 }
      }
    }
    background: Rectangle {
      radius: root.tokens.rowRadius
      color: networkRow.active ? Qt.alpha(root.accent, 0.08)
        : networkRow.hovered || networkRow.activeFocus ? Qt.alpha(root.tokens.text, 0.05) : root.tokens.background
      border.width: networkRow.activeFocus ? 2 : 1
      border.color: networkRow.activeFocus ? root.tokens.cyan
        : networkRow.active ? Qt.alpha(root.accent, 0.35) : root.tokens.hairline
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 12
    ConnectionMark {
      kind: "wifi"
      accent: root.accent
      active: root.service.radio
      tokens: root.tokens
    }
    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: 2
      Eyebrow { text: "WIRELESS" }
      Text {
        Layout.fillWidth: true
        text: "Wi-Fi"
        textFormat: Text.PlainText
        color: root.tokens.text
        font { family: root.tokens.font; pixelSize: 18; weight: Font.Medium }
      }
      Caption {
        text: root.service.busy ? root.service.pending
          : !root.service.available || !root.service.hardware || !root.service.adapters.length ? root.service.state
          : root.service.radio ? root.service.adapter ? root.service.adapter.name + " · "
            + (root.service.adapter.state === "connected" ? "Connected" : root.service.adapter.state) : "Ready"
          : "Wireless is turned off"
      }
    }
    PanelSwitch {
      tokens: root.tokens
      accent: root.accent
      checked: root.service.radio
      enabled: root.service.available && root.service.hardware && root.service.adapters.length > 0 && !root.service.busy
      opacity: enabled ? 1 : 0.45
      Accessible.name: "Wi-Fi power"
      onClicked: root.service.setRadio(checked)
    }
  }
  Choice {
    visible: root.service.adapters.length > 1
    enabled: !root.service.busy
    model: root.service.adapters.map(d => d.name)
    currentIndex: Math.max(0, root.service.adapters.findIndex(d => d.name === root.service.selected))
    onActivated: { root.reset(); root.service.selected = currentText; }
    Accessible.name: "Wi-Fi adapter"
  }
  Caption {
    visible: root.service.adapters.length === 1
    text: "ADAPTER  /  " + root.service.selected
    font { family: root.tokens.mono; pixelSize: 9 }
  }
  Rectangle {
    Layout.fillWidth: true
    visible: root.service.error !== ""
    implicitHeight: errorText.implicitHeight + 24
    radius: root.tokens.rowRadius
    color: Qt.alpha(root.tokens.alert, 0.1)
    border.color: Qt.alpha(root.tokens.alert, 0.35)
    Text {
      id: errorText
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
      text: root.service.error
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      color: root.tokens.alert
      font { family: root.tokens.font; pixelSize: 11 }
    }
  }

  // A dedicated view keeps credentials and confirmation actions in reach.
  ColumnLayout {
    Layout.fillWidth: true
    visible: root.form
    spacing: 10
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
    Action { text: "All networks"; symbol: "‹"; onClicked: root.reset() }
    Eyebrow { text: root.hiddenNetwork ? "HIDDEN NETWORK" : "CONNECT" }
    Label { text: root.hiddenNetwork ? "Join a hidden network" : root.targetSsid; font { pixelSize: 16; weight: Font.Medium } }
    Caption { text: root.hiddenNetwork ? "Enter the network name exactly as it is configured." : root.securityLabel(root.security) }
    Caption { visible: root.hiddenNetwork; text: "Network name" }
    Field {
      id: ssid
      visible: root.hiddenNetwork
      onTextEdited: root.hiddenProfiles()
      placeholderText: "SSID"
      Accessible.name: "Exact SSID"
      onAccepted: if (root.canSubmit) root.submit()
    }
    Caption { visible: root.hiddenNetwork; text: "Security" }
    Choice {
      id: securityChoice
      visible: root.hiddenNetwork
      model: ["Open", "WPA/WPA2 Personal", "WPA3 Personal"]
      onActivated: { root.security = ["open", "wpa-psk", "sae"][currentIndex]; password.text = ""; root.hiddenProfiles(); }
      Accessible.name: "Network security"
    }
    Caption { visible: root.choices.length > 1; text: "Saved connection" }
    Choice {
      id: profile
      visible: root.choices.length > 1
      model: root.choices.map((p, index) => p.name + " · " + (index + 1))
      Accessible.name: "Saved profile"
    }
    Caption { visible: root.choices.length > 0; text: root.personalPassword ? "Use the saved password or enter a new one." : "This connection will use its saved settings." }
    Caption { visible: root.personalPassword; text: "Password" }
    Field {
      id: password
      objectName: "wifiPassword"
      visible: root.personalPassword
      placeholderText: root.choices.length ? "Saved password" : "Enter password"
      Accessible.name: "Wi-Fi password"
      echoMode: reveal.checked ? TextInput.Normal : TextInput.Password
      inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
      onAccepted: if (root.canSubmit) root.submit()
    }
    CheckBox {
      id: reveal
      visible: root.personalPassword
      text: "Show password"
      spacing: 8
      padding: 0
      implicitHeight: 30
      indicator: Rectangle {
        implicitWidth: 16; implicitHeight: 16
        y: (reveal.height - height) / 2
        radius: 3
        color: reveal.checked ? root.accent : Qt.alpha(root.tokens.surface, 0.7)
        border.color: reveal.activeFocus ? root.accent : root.tokens.border
        Text {
          anchors.centerIn: parent
          visible: reveal.checked
          text: "✓"
          color: root.tokens.background
          font.pixelSize: 12
        }
      }
      contentItem: Text {
        leftPadding: 24
        text: reveal.text
        color: root.tokens.muted
        verticalAlignment: Text.AlignVCenter
        font { family: root.tokens.font; pixelSize: 11 }
      }
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Action { id: connectButton; Layout.fillWidth: true; text: "Connect"; selected: true; enabled: root.canSubmit; onClicked: root.submit() }
      Action { Layout.fillWidth: true; text: "Cancel"; tint: root.tokens.muted; onClicked: root.reset() }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.forgetUuid !== ""
    spacing: 10
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
    Eyebrow { text: "FORGET NETWORK"; color: root.tokens.alert }
    Label { text: "Forget this network?"; font { pixelSize: 16; weight: Font.Medium } }
    Label { text: root.forgetName; color: root.accent }
    Caption { text: "Its saved settings and password will be removed." }
    Label {
      visible: root.service.devices.some(d => d.uuid === root.forgetUuid && d.state === "connected")
      text: "You are connected to this network. Forgetting it will disconnect you."
      color: root.tokens.alert
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Action { Layout.fillWidth: true; text: "Forget"; destructive: true; enabled: !root.service.busy; onClicked: { root.service.forget(root.forgetUuid); root.reset(); } }
      Action { Layout.fillWidth: true; text: "Cancel"; tint: root.tokens.muted; onClicked: root.reset() }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: !root.form && root.forgetUuid === ""
    spacing: 10
    Rectangle {
      Layout.fillWidth: true
      visible: root.connected && root.service.radio
      implicitHeight: hero.implicitHeight + 24
      radius: 10
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.tint(root.tokens.background, Qt.alpha(root.accent, 0.09)) }
        GradientStop { position: 1; color: root.tokens.background }
      }
      border.color: Qt.alpha(root.accent, 0.25)
      RowLayout {
        id: hero
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 10
        ColumnLayout {
          Layout.fillWidth: true
          Layout.minimumWidth: 0
          spacing: 2
          Eyebrow { text: "CURRENT NETWORK" }
          Text {
            Layout.fillWidth: true
            text: root.currentNetwork ? root.currentNetwork.ssid : root.service.adapter ? root.service.adapter.connection : ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.tokens.text
            font { family: root.tokens.font; pixelSize: 14; weight: Font.Medium }
          }
          Caption {
            text: "Connected" + (root.currentNetwork ? " · " + root.currentNetwork.signal + "% · " + root.securityLabel(root.currentNetwork.security) : "")
          }
        }
        SignalMeter {
          strength: root.currentNetwork ? root.currentNetwork.signal : 0
          highlighted: true
        }
        Action {
          implicitHeight: 32
          text: "Disconnect"
          tint: root.tokens.muted
          enabled: !root.service.busy
          onClicked: root.service.disconnect()
        }
      }
    }
    ConnectionTabs {
      tokens: root.tokens
      accent: root.accent
      current: root.section
      options: [
        {key: "available", label: "Available · " + root.nearbyCount},
        {key: "saved", label: "Saved · " + root.service.profiles.length}
      ]
      onSelected: key => root.section = key
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Caption {
        Layout.fillWidth: true
        text: root.section === "available"
          ? root.service.pending === "Scanning…" ? "Searching for networks…"
            : root.nearbyCount + (root.nearbyCount === 1 ? " nearby network" : " nearby networks")
          : root.service.profiles.length + (root.service.profiles.length === 1 ? " saved network" : " saved networks")
      }
      Action {
        implicitHeight: 30
        text: root.section === "available" ? "Scan" : "Refresh"
        symbol: "↻"
        enabled: root.section === "available" ? root.canConnect : !root.service.loading
        onClicked: root.section === "available" ? root.service.scan() : root.service.refresh()
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.section === "available"
      spacing: 6
      Repeater {
        model: root.visibleNetworks.filter(n => !n.active)
        NetworkRow {
          required property var modelData
          name: modelData.ssid
          detail: root.securityLabel(modelData.security) + " · " + modelData.signal + "%"
          strength: modelData.signal
          enabled: root.canConnect
          onClicked: root.choose(modelData)
        }
      }
      EmptyState {
        visible: root.nearbyCount === 0
        tokens: root.tokens
        accent: root.accent
        mark: root.service.radio ? "search" : "wifi"
        title: !root.service.available || !root.service.adapters.length ? "Wi-Fi unavailable"
          : !root.service.hardware ? "Hardware blocked"
          : !root.service.radio ? "Wireless is off"
          : root.service.loading ? "Looking for networks…"
          : root.connected ? "No other networks" : "No networks in range"
        message: !root.service.available ? "Check that NetworkManager is running."
          : !root.service.adapters.length ? "Connect a Wi-Fi adapter to get started."
          : !root.service.hardware ? "Enable Wi-Fi with the hardware switch."
          : !root.service.radio ? "Turn on Wi-Fi to discover nearby networks."
          : root.service.loading ? "The list refreshes automatically."
          : root.connected && root.currentNetwork ? "You are connected to " + root.currentNetwork.ssid + ". Scan again for more."
          : "Scan again, or join a hidden network below."
      }
      Action {
        Layout.fillWidth: true
        text: "Hidden network"
        symbol: "+"
        enabled: root.canConnect
        onClicked: { root.reset(); root.hiddenNetwork = true; root.security = "open"; securityChoice.currentIndex = 0; root.form = true; ssid.forceActiveFocus(); }
      }
    }
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.section === "saved"
      spacing: 8
      Repeater {
        model: root.service.profiles
        ColumnLayout {
          id: savedProfile
          required property var modelData
          readonly property bool activeProfile: root.service.devices.some(d => d.uuid === modelData.uuid && d.state === "connected")
          Layout.fillWidth: true
          spacing: 2
          NetworkRow {
            name: savedProfile.modelData.name
            detail: (savedProfile.activeProfile ? "Connected" : savedProfile.modelData.ssid || "Saved network")
              + " · " + root.securityLabel(savedProfile.modelData.security)
              + (root.service.profiles.filter(p => p.name === savedProfile.modelData.name).length > 1 ? " · Connection " + (root.service.profiles.filter(p => p.name === savedProfile.modelData.name).findIndex(p => p.uuid === savedProfile.modelData.uuid) + 1) : "")
            active: savedProfile.activeProfile
            enabled: root.canConnect && (!savedProfile.modelData.iface || savedProfile.modelData.iface === root.service.selected)
            Accessible.name: name + ". " + detail + ". Open connection options"
            onClicked: root.openSaved(savedProfile.modelData)
          }
          RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Caption { Layout.fillWidth: true; text: savedProfile.modelData.iface || "Any Wi-Fi adapter"; font.pixelSize: 9 }
            Action {
              implicitHeight: 26
              text: "Forget"
              destructive: true
              quiet: true
              enabled: !root.service.busy
              Accessible.name: "Forget " + savedProfile.modelData.name
              onClicked: { root.reset(); root.forgetUuid = savedProfile.modelData.uuid; root.forgetName = savedProfile.modelData.name; }
            }
          }
        }
      }
      EmptyState {
        visible: root.service.profiles.length === 0
        tokens: root.tokens
        accent: root.accent
        mark: "wifi"
        title: "No saved networks"
        message: "Networks you join will be stored here for quick reconnection."
      }
    }
  }
}
