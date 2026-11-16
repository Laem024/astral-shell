pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import "../data" as Data

PanelCard {
  id: root
  title: ""
  radius: 12
  contentSpacing: 14
  readonly property color accent: root.tokens.gold
  readonly property var service: Data.VpnData
  property string section: "profiles"
  property string importName: ""
  property string importPath: ""
  property string importType: "wireguard"
  property string pendingDelete: ""
  readonly property string home: Quickshell.env("HOME")
  readonly property var orderedProfiles: service.profiles.slice().sort((a, b) => Number(b.active) - Number(a.active) || a.name.localeCompare(b.name))
  readonly property var pendingProfile: service.profiles.find(profile => profile.uuid === pendingDelete) || null
  readonly property bool importTypeFixed: /\.ovpn$/i.test(importName)
  readonly property string importBaseName: importName.replace(/\.(conf|ovpn)$/i, "")
  readonly property bool duplicateName: importBaseName !== "" && service.profiles.some(profile => profile.name.toLowerCase() === importBaseName.toLowerCase())
  Component.onCompleted: { service.viewers++; service.refresh(); }
  Component.onDestruction: { service.viewers--; }
  onVisibleChanged: if (!visible) { section = "profiles"; clearImport(); pendingDelete = ""; }

  function fileUrl(path) {
    return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F");
  }
  function pathOf(url) {
    const value = url.toString();
    if (!value.startsWith("file://")) return value;
    try { return decodeURIComponent(value.slice(7)); } catch (error) { return value.slice(7); }
  }
  function typeLabel(profile) {
    return profile.type === "wireguard" ? "WireGuard" : "OpenVPN";
  }
  function kindOf(name) {
    return /\.ovpn$/i.test(name) ? "openvpn" : "wireguard";
  }
  function openImport() {
    if (service.busy || !service.available) return;
    section = "import";
    clearImport();
  }
  function closeImport() {
    section = "profiles";
    clearImport();
  }
  function clearImport() {
    importName = "";
    importPath = "";
    importType = "wireguard";
  }
  function chooseFile(name, url) {
    if (!/\.(conf|ovpn)$/i.test(name)) return;
    const path = pathOf(url);
    if (!path.startsWith("/")) return;
    importName = name;
    importPath = path;
    importType = kindOf(name);
  }

  component Label: Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    color: root.tokens.text
    font { family: root.tokens.font; pixelSize: 12 }
  }
  component Caption: Label {
    color: root.tokens.muted
    font.pixelSize: 10
  }
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
    implicitHeight: 36
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
  component Field: TextField {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: 40
    leftPadding: 12; rightPadding: 12
    color: root.tokens.text
    placeholderTextColor: root.tokens.muted
    selectionColor: root.accent
    selectedTextColor: root.tokens.background
    font { family: root.tokens.font; pixelSize: 12 }
    background: Rectangle {
      radius: 7
      color: Qt.alpha(root.tokens.surface, 0.7)
      border.color: parent.activeFocus ? root.accent : root.tokens.border
    }
  }
  component VpnRow: Button {
    id: vpnRow
    required property string name
    property string detail: ""
    property bool active: false
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    implicitHeight: 56
    leftPadding: 12; rightPadding: 12; topPadding: 10; bottomPadding: 10
    opacity: enabled ? 1 : 0.5
    Accessible.name: name + ". " + detail + (active ? ". Disconnect" : ". Connect")

    contentItem: RowLayout {
      spacing: 10
      ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        spacing: 2
        Text {
          Layout.fillWidth: true
          text: vpnRow.name
          textFormat: Text.PlainText
          elide: Text.ElideRight
          color: vpnRow.active ? root.accent : root.tokens.text
          font { family: root.tokens.font; pixelSize: 13; weight: Font.Medium }
        }
        Caption { text: vpnRow.detail }
      }
      StatusPill {
        visible: vpnRow.active
        tokens: root.tokens
        text: "LIVE"
        accent: root.accent
      }
      Text {
        visible: !vpnRow.active
        text: "CONNECT"
        textFormat: Text.PlainText
        color: root.tokens.muted
        font { family: root.tokens.mono; pixelSize: 8; letterSpacing: 0.5 }
      }
      Text {
        visible: !vpnRow.active
        text: "›"
        color: root.tokens.muted
        font { family: root.tokens.mono; pixelSize: 16 }
      }
    }
    background: Rectangle {
      radius: 9
      color: vpnRow.active ? Qt.alpha(root.accent, 0.06)
        : vpnRow.hovered ? Qt.alpha(root.tokens.surface, 0.7) : "transparent"
      border.color: vpnRow.activeFocus ? root.accent
        : vpnRow.active ? Qt.alpha(root.accent, 0.3) : "transparent"
    }
  }
  component FileRow: Button {
    id: fileRow
    required property string fileName
    required property url fileUrl
    required property bool fileIsDir
    implicitHeight: 44
    leftPadding: 8; rightPadding: 8
    Accessible.name: (fileIsDir ? "Folder: " : "VPN file: ") + fileName
    contentItem: RowLayout {
      spacing: 10
      Rectangle {
        implicitWidth: 30
        implicitHeight: 22
        radius: 5
        color: fileRow.fileIsDir ? Qt.alpha(root.tokens.muted, 0.08) : Qt.alpha(root.accent, 0.07)
        border.color: fileRow.fileIsDir ? root.tokens.border : Qt.alpha(root.accent, 0.2)
        Text {
          anchors.centerIn: parent
          text: fileRow.fileIsDir ? "DIR" : root.kindOf(fileRow.fileName) === "openvpn" ? "OV" : "WG"
          color: fileRow.fileIsDir ? root.tokens.muted : root.accent
          font { family: root.tokens.mono; pixelSize: 8 }
        }
      }
      Text {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: fileRow.fileName
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        color: root.tokens.text
        font { family: root.tokens.font; pixelSize: 11 }
      }
      Text {
        text: fileRow.fileIsDir ? "FOLDER" : root.kindOf(fileRow.fileName) === "openvpn" ? "OPENVPN" : "WIREGUARD"
        textFormat: Text.PlainText
        color: root.tokens.muted
        font { family: root.tokens.mono; pixelSize: 8 }
      }
    }
    background: Rectangle {
      radius: 7
      color: fileRow.hovered ? Qt.alpha(root.tokens.surface, 0.7) : "transparent"
      border.color: fileRow.activeFocus ? root.accent : "transparent"
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: 12
    ConnectionMark {
      kind: "vpn"
      tokens: root.tokens
      accent: root.accent
      active: root.service.active.length > 0
    }
    ColumnLayout {
      Layout.fillWidth: true
      Layout.minimumWidth: 0
      spacing: 2
      Eyebrow { text: "PRIVATE TUNNEL" }
      Text {
        Layout.fillWidth: true
        text: "VPN"
        textFormat: Text.PlainText
        color: root.tokens.text
        font { family: root.tokens.font; pixelSize: 19; weight: Font.Medium }
      }
      Caption { text: root.service.state }
    }
    StatusPill {
      visible: root.service.active.length > 0
      tokens: root.tokens
      text: root.service.active.length + " LIVE"
      accent: root.accent
    }
  }
  Rectangle {
    Layout.fillWidth: true
    visible: root.service.error !== ""
    implicitHeight: errorText.implicitHeight + 24
    radius: 8
    color: Qt.alpha(root.tokens.alert, 0.07)
    border.color: Qt.alpha(root.tokens.alert, 0.3)
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

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.section === "profiles" && root.pendingDelete === ""
    spacing: 8
    Repeater {
      model: root.orderedProfiles
      ColumnLayout {
        id: profileItem
        required property var modelData
        readonly property bool live: profileItem.modelData.active
        Layout.fillWidth: true
        spacing: 4
        VpnRow {
          name: profileItem.modelData.name
          detail: root.typeLabel(profileItem.modelData) + (profileItem.live ? " · Connected" : " · Disconnected")
          active: profileItem.live
          enabled: root.service.available && !root.service.busy
          onClicked: root.service.toggle(profileItem.modelData.uuid)
        }
        RowLayout {
          Layout.fillWidth: true
          spacing: 8
          StatusPill {
            tokens: root.tokens
            text: profileItem.modelData.type === "wireguard" ? "WIREGUARD" : "OPENVPN"
            accent: profileItem.modelData.type === "wireguard" ? root.accent : root.tokens.lavender
          }
          Item { Layout.fillWidth: true }
          Action {
            implicitHeight: 26
            text: "Remove"
            destructive: true
            quiet: true
            enabled: !root.service.busy
            Accessible.name: "Remove " + profileItem.modelData.name
            onClicked: root.pendingDelete = profileItem.modelData.uuid
          }
        }
      }
    }
    EmptyState {
      visible: !root.orderedProfiles.length && !root.service.loading
      tokens: root.tokens
      accent: root.accent
      mark: "vpn"
      title: root.service.available ? "No VPN profiles yet" : "VPN unavailable"
      message: root.service.available
        ? "Import a WireGuard .conf or OpenVPN .ovpn file. NetworkManager stores the profile; this panel never displays its keys."
        : "Check that NetworkManager is running."
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Action {
        text: root.service.loading ? "Refreshing…" : "Refresh"
        symbol: "↻"
        enabled: root.service.available && !root.service.loading && !root.service.busy
        onClicked: root.service.refresh()
      }
      Action {
        Layout.fillWidth: true
        text: "Import profile"
        symbol: "+"
        selected: true
        enabled: root.service.available && !root.service.busy
        onClicked: root.openImport()
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.section === "import" && root.pendingDelete === ""
    spacing: 10
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
    Action { text: "All profiles"; symbol: "‹"; onClicked: root.closeImport() }
    Eyebrow { text: "IMPORT PROFILE" }
    Label { text: "Import a VPN profile"; font { pixelSize: 16; weight: Font.Medium } }
    Caption {
      text: "Choose a WireGuard .conf or OpenVPN .ovpn file. NetworkManager reads the file and saves a profile; this panel never reads or shows its keys."
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Action {
        text: "Up"
        symbol: "↑"
        enabled: files.folder.toString() !== files.parentFolder.toString()
        onClicked: files.folder = files.parentFolder
      }
      Field {
        id: folderPath
        Component.onCompleted: text = root.pathOf(files.folder)
        placeholderText: "Folder path"
        Accessible.name: "Folder path"
        onAccepted: if (text.startsWith("/")) files.folder = root.fileUrl(text)
      }
    }
    ListView {
      id: fileList
      Layout.fillWidth: true
      Layout.preferredHeight: 210
      clip: true
      model: files
      ScrollBar.vertical: ScrollBar {}
      onVisibleChanged: if (visible) forceActiveFocus()
      delegate: FileRow {
        required property int index
        width: fileList.width
        onClicked: {
          fileList.currentIndex = index;
          if (fileIsDir) files.folder = fileUrl;
          else root.chooseFile(fileName, fileUrl);
        }
      }
      Keys.onReturnPressed: {
        if (currentIndex < 0 || currentIndex >= files.count) return;
        if (files.isFolder(currentIndex)) files.folder = files.get(currentIndex, "fileUrl");
        else root.chooseFile(files.get(currentIndex, "fileName"), files.get(currentIndex, "fileUrl"));
      }
    }
    Caption {
      visible: files.count === 0 && files.status !== FolderListModel.Loading
      text: files.status === FolderListModel.Ready ? "No .conf or .ovpn files here. Check the path or go up." : "Choose a readable folder."
    }
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.importName !== ""
      spacing: 10
      Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
      Eyebrow { text: "SELECTED FILE" }
      Label { text: root.importName; font { pixelSize: 15; weight: Font.Medium } }
      Caption { text: root.importTypeFixed ? "OpenVPN configuration" : "Configuration file" }
      Caption { visible: !root.importTypeFixed; text: "File type" }
      RowLayout {
        Layout.fillWidth: true
        visible: !root.importTypeFixed
        spacing: 8
        Action {
          Layout.fillWidth: true
          text: "WireGuard"
          selected: root.importType === "wireguard"
          onClicked: root.importType = "wireguard"
        }
        Action {
          Layout.fillWidth: true
          text: "OpenVPN"
          selected: root.importType === "openvpn"
          onClicked: root.importType = "openvpn"
        }
      }
      Caption {
        visible: root.duplicateName
        text: "A profile named " + root.importBaseName + " already exists. Importing creates another profile."
        color: root.tokens.gold
      }
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Action {
          Layout.fillWidth: true
          text: "Import"
          selected: true
          enabled: !root.service.busy
          onClicked: root.service.importFile(root.importPath, root.importType)
        }
        Action { Layout.fillWidth: true; text: "Cancel"; tint: root.tokens.muted; onClicked: root.clearImport() }
      }
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    visible: root.pendingDelete !== ""
    spacing: 10
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
    Eyebrow { text: "REMOVE PROFILE"; color: root.tokens.alert }
    Label { text: root.pendingProfile ? root.pendingProfile.name : "VPN profile"; font { pixelSize: 16; weight: Font.Medium } }
    Caption { text: root.pendingProfile ? root.typeLabel(root.pendingProfile) + " profile" : "" }
    Caption {
      text: root.pendingProfile && root.pendingProfile.active
        ? "This VPN is connected. Removing its profile will end the connection."
        : "The saved profile is deleted from NetworkManager. The original file is not touched."
      color: root.pendingProfile && root.pendingProfile.active ? root.tokens.alert : root.tokens.muted
    }
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Action {
        Layout.fillWidth: true
        text: "Remove profile"
        destructive: true
        enabled: !root.service.busy
        onClicked: { root.service.remove(root.pendingDelete); root.pendingDelete = ""; }
      }
      Action { Layout.fillWidth: true; text: "Cancel"; tint: root.tokens.muted; onClicked: root.pendingDelete = "" }
    }
  }

  FolderListModel {
    id: files
    folder: root.fileUrl(root.home)
    nameFilters: ["*.conf", "*.ovpn"]
    caseSensitive: false
    showDirs: true
    showDotAndDotDot: false
    showHidden: false
    sortField: FolderListModel.Name
    showDirsFirst: true
    showFiles: true
    onFolderChanged: folderPath.text = root.pathOf(folder)
  }
  Connections {
    target: root.service
    function onImported() { root.section = "profiles"; root.clearImport(); }
  }
  Keys.onEscapePressed: event => {
    if (root.importName !== "") root.clearImport();
    else if (root.section === "import") root.closeImport();
    else if (root.pendingDelete !== "") root.pendingDelete = "";
    else event.accepted = false;
  }
}
