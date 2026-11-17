pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import "../data" as Data
import "../../common" as Design
import "../components" as Components

FocusScope {
  id: root
  required property Design.Theme tokens
  property string mode: "avatar"
  property real bannerAspect: 5
  readonly property bool banner: mode === "banner"
  readonly property bool busy: banner ? Data.BannerData.busy : Data.UserData.busy
  property bool editing: false
  property bool submitted: false
  property url selection: ""
  readonly property string error: banner ? Data.BannerData.error : Data.UserData.error
  signal closed()
  focus: true

  function back(): void {
    if (busy) return;
    if (editing) { editing = false; selection = ""; gallery.forceActiveFocus(); }
    else closed();
  }
  function choose(source: url): void {
    selection = source;
    crop.reset();
    editing = true;
    cropFrame.forceActiveFocus();
  }
  function save(): void {
    if (busy || crop.status !== Image.Ready) return;
    submitted = true;
    if (banner) Data.BannerData.save(selection, {zoom: crop.zoom, focusX: crop.focusX, focusY: crop.focusY});
    else Data.UserData.saveAvatar(crop);
  }
  Keys.onEscapePressed: event => { root.back(); event.accepted = true; }
  Connections {
    target: Data.UserData
    function onSaved() { if (!root.banner && root.submitted) root.closed(); }
    function onErrorChanged() { if (!root.banner && Data.UserData.error) root.submitted = false; }
  }
  Connections {
    target: Data.BannerData
    function onSaved() { if (root.banner && root.submitted) root.closed(); }
    function onErrorChanged() { if (root.banner && Data.BannerData.error) root.submitted = false; }
  }
  Component.onCompleted: {
    if (banner && Data.BannerData.source) {
      selection = Data.BannerData.source;
      crop.zoom = Data.BannerData.zoom;
      crop.focusX = Data.BannerData.focusX;
      crop.focusY = Data.BannerData.focusY;
      editing = true;
      cropFrame.forceActiveFocus();
    } else if (!banner && Data.UserData.avatar) {
      choose(Data.UserData.avatar);
    } else gallery.forceActiveFocus();
  }

  FolderListModel {
    id: files
    folder: Data.BannerData.fileUrl(Data.UserData.home)
    nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.PNG", "*.JPG", "*.JPEG"]
    caseSensitive: false
    showDirs: true; showDotAndDotDot: false; showHidden: false
    sortField: FolderListModel.Name
    showDirsFirst: true
    showFiles: true
  }
  ColumnLayout {
    anchors.fill: parent
    spacing: 10
    Text {
      Layout.fillWidth: true
      text: root.banner ? "Panel banner" : "Account photo"
      color: root.tokens.text; font { family: root.tokens.font; pixelSize: 18; weight: Font.Medium }
    }
    Text {
      Layout.fillWidth: true
      text: root.banner ? "A background shared by your panels." : "This changes your system account photo."
      color: root.tokens.muted; wrapMode: Text.Wrap
      font { family: root.tokens.font; pixelSize: 12 }
    }
    RowLayout {
      visible: !root.editing
      Layout.fillWidth: true
      PanelButton {
        tokens: root.tokens; text: "Up"; enabled: !root.busy && files.folder !== files.parentFolder
        onClicked: files.folder = files.parentFolder
      }
      TextField {
        Layout.fillWidth: true
        enabled: !root.busy
        text: decodeURIComponent(files.folder.toString().replace(/^file:\/\//, ""))
        color: root.tokens.text
        font.family: root.tokens.font
        background: Rectangle {
          color: root.tokens.background; radius: root.tokens.rowRadius
          border.width: parent.activeFocus ? 2 : 1
          border.color: parent.activeFocus ? root.tokens.cyan : root.tokens.border
        }
        Accessible.name: "Folder path"
        onAccepted: {
          if (text.startsWith("/")) files.folder = Data.BannerData.fileUrl(text);
        }
      }
    }
    GridView {
      id: gallery
      visible: !root.editing
      Layout.fillWidth: true; Layout.fillHeight: true
      clip: true; model: files
      cellWidth: width / Math.max(1, Math.floor(width / 112)); cellHeight: 108
      keyNavigationEnabled: true
      ScrollBar.vertical: ScrollBar {}
      delegate: PanelButton {
        id: entry
        required property int index
        required property string fileName
        required property url fileUrl
        required property bool fileIsDir
        width: gallery.cellWidth - 6; height: gallery.cellHeight - 6
        tokens: root.tokens; enabled: !root.busy
        selected: gallery.currentIndex === index
        text: fileName
        Accessible.name: (fileIsDir ? "Folder: " : "Image: ") + fileName
        onClicked: {
          gallery.currentIndex = index;
          if (fileIsDir) files.folder = fileUrl;
          else root.choose(fileUrl);
        }
        contentItem: ColumnLayout {
          spacing: 4
          Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            Image {
              id: thumbnail
              anchors.fill: parent
              source: entry.fileIsDir ? "" : entry.fileUrl
              sourceSize: Qt.size(160, 120)
              fillMode: Image.PreserveAspectFit; asynchronous: true
            }
            Text {
              anchors.centerIn: parent
              visible: entry.fileIsDir || thumbnail.status !== Image.Ready
              text: entry.fileIsDir ? "Folder" : thumbnail.status === Image.Loading ? "Loading…" : "Invalid image"
              color: root.tokens.muted; font { family: root.tokens.font; pixelSize: 11 }
            }
          }
          Text {
            Layout.fillWidth: true
            text: entry.fileName; textFormat: Text.PlainText
            elide: Text.ElideMiddle; color: root.tokens.text
            font { family: root.tokens.font; pixelSize: 11 }
          }
        }
      }
      function activateCurrent(): void {
        if (currentIndex >= 0 && currentIndex < files.count) {
          if (files.isFolder(currentIndex)) files.folder = files.get(currentIndex, "fileUrl");
          else root.choose(files.get(currentIndex, "fileUrl"));
        }
      }
      Keys.onReturnPressed: activateCurrent()
      Keys.onEnterPressed: activateCurrent()
      Text {
        anchors.centerIn: parent
        visible: files.status === FolderListModel.Loading || files.count === 0
        text: files.status === FolderListModel.Loading ? "Loading folder…" : "No PNG/JPEG images or folders here. Check the path."
        width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
        color: root.tokens.muted; font.family: root.tokens.font
      }
    }
    Item {
      visible: root.editing
      Layout.fillWidth: true; Layout.fillHeight: true
      Layout.minimumHeight: 80
      Rectangle {
        id: cropFrame
        anchors.centerIn: parent
        readonly property real aspect: root.banner ? Math.max(0.1, root.bannerAspect) : 1
        width: Math.min(parent.width - 4, (parent.height - 4) * aspect)
        height: width / aspect
        color: root.tokens.background
        activeFocusOnTab: true
        border.color: activeFocus ? root.tokens.cyan : root.tokens.border
        Accessible.role: Accessible.Pane
        Accessible.name: "Crop preview. Arrow keys move image; plus and minus zoom; zero resets."
        Components.CropImage {
          id: crop
          anchors.fill: parent
          source: root.selection
        }
        // Decorations and interaction are siblings, excluded from grabToImage.
        Rectangle {
          anchors.fill: parent
          color: "transparent"
          border.color: cropFrame.activeFocus ? root.tokens.cyan : root.tokens.border
        }
        MouseArea {
          anchors.fill: parent
          enabled: !root.busy && crop.status === Image.Ready
          cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
          property point previous
          onPressed: mouse => { cropFrame.forceActiveFocus(); previous = Qt.point(mouse.x, mouse.y); }
          onPositionChanged: mouse => {
            if (!pressed) return;
            crop.pan(mouse.x - previous.x, mouse.y - previous.y);
            previous = Qt.point(mouse.x, mouse.y);
          }
          onWheel: wheel => { crop.zoom = Math.max(1, Math.min(4, crop.zoom + (wheel.angleDelta.y > 0 ? 0.1 : -0.1))); }
        }
        Keys.onPressed: event => {
          if (root.busy) return;
          const step = event.modifiers & Qt.ShiftModifier ? 32 : 8;
          if (event.key === Qt.Key_Left) crop.pan(-step, 0);
          else if (event.key === Qt.Key_Right) crop.pan(step, 0);
          else if (event.key === Qt.Key_Up) crop.pan(0, -step);
          else if (event.key === Qt.Key_Down) crop.pan(0, step);
          else if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) crop.zoom = Math.min(4, crop.zoom + 0.1);
          else if (event.key === Qt.Key_Minus) crop.zoom = Math.max(1, crop.zoom - 0.1);
          else if (event.key === Qt.Key_0) crop.reset();
          else return;
          event.accepted = true;
        }
        Text {
          anchors.centerIn: parent
          visible: crop.status !== Image.Ready
          text: crop.status === Image.Loading ? "Loading image…" : "Unable to open this image."
          color: root.tokens.muted; font.family: root.tokens.font
        }
      }
    }
    RowLayout {
      visible: root.editing
      Layout.fillWidth: true
      Text { text: "Zoom"; color: root.tokens.text; font.family: root.tokens.font }
      Slider {
        Layout.fillWidth: true
        from: 1; to: 4; stepSize: 0.05; value: crop.zoom
        enabled: !root.busy && crop.status === Image.Ready
        Accessible.name: "Image zoom"
        onMoved: crop.zoom = value
      }
      Text { text: crop.zoom.toFixed(1) + "×"; color: root.tokens.muted; font.family: root.tokens.mono }
      PanelButton { tokens: root.tokens; text: "Reset"; enabled: !root.busy; onClicked: crop.reset() }
    }
    Text {
      Layout.fillWidth: true
      visible: root.editing
      text: "Drag to move · Arrows to move · +/− to zoom · 0 to reset"
      color: root.tokens.muted; font { family: root.tokens.font; pixelSize: 11 }
      wrapMode: Text.Wrap
    }
    Text {
      Layout.fillWidth: true; visible: text !== ""
      text: root.error; color: root.tokens.alert; font.family: root.tokens.font; wrapMode: Text.Wrap
    }
    Flow {
      Layout.fillWidth: true
      spacing: 8
      PanelButton { tokens: root.tokens; visible: root.editing; text: "Load image"; enabled: !root.busy; onClicked: root.back() }
      PanelButton { tokens: root.tokens; text: "Cancel"; enabled: !root.busy; onClicked: root.closed() }
      PanelButton {
        tokens: root.tokens; visible: root.banner && !!Data.BannerData.file
        text: "Remove banner"; destructive: true; enabled: !root.busy
        onClicked: { root.submitted = true; Data.BannerData.remove(); }
      }
      PanelButton {
        tokens: root.tokens; visible: root.editing
        text: root.busy ? "Saving…" : "Save"
        enabled: !root.busy && crop.status === Image.Ready && (root.banner || !!Data.UserData.accountPath)
        onClicked: root.save()
      }
    }
  }
}
