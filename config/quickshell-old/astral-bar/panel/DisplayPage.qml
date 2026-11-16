pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../design" as Design
import "../data" as Data
import "../components" as Components

ScrollView {
  id: root
  required property Design.Theme tokens
  signal captureRequested()
  readonly property string task: Data.CapturePreferences.task
  readonly property string mode: Data.CapturePreferences.source
  readonly property string audio: Data.CapturePreferences.audio
  readonly property bool busy: Data.CaptureData.busy
  readonly property bool canCapture: !busy && (outputs.count > 0 || mode !== "monitor")
  readonly property string lastResult: task === "record" ? Data.CaptureData.lastVideo : Data.CaptureData.lastScreenshot
  readonly property var lastEntry: Data.NotificationData.entries.find(entry => entry.file === root.lastResult) || null
  readonly property string statusLabel: ({idle: "Ready to capture", hiding: "Preparing capture", selecting: "Select your source", preparing: "Preparing recording", recording: "Recording in progress", finalizing: "Saving recording", error: "Capture failed"})[Data.CaptureData.state] || "Ready to capture"
  readonly property string audioSummary: {
    const sink = Data.AudioData.label(Data.AudioData.sink);
    const source = Data.AudioData.label(Data.AudioData.source);
    if (root.audio === "system") return "System: " + sink;
    if (root.audio === "microphone") return "Microphone: " + source;
    if (root.audio === "both") return "System: " + sink + " · Microphone: " + source;
    return "Record without sound.";
  }
  contentWidth: availableWidth
  clip: true
  layer.enabled: true
  ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
  function start(kind): void {
    if (Data.CaptureData.prepare(kind, mode, mode === "monitor" ? outputs.currentText : "", kind === "record" ? audio : "none")) captureRequested();
  }
  component Caption: Text {
    Layout.fillWidth: true
    Layout.minimumWidth: 0
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    color: root.tokens.muted
    font { family: root.tokens.font; pixelSize: 11 }
  }
  component Section: PanelCard {
    tokens: root.tokens
    radius: 10
    contentSpacing: 14
  }
  component Choice: PanelButton {
    id: choice
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.minimumWidth: 0
    tokens: root.tokens
    implicitHeight: 36
    opacity: enabled ? 1 : 0.45
    contentItem: Text {
      text: choice.text
      color: choice.selected ? root.tokens.cyan : root.tokens.muted
      font { family: root.tokens.font; pixelSize: 11; weight: choice.selected ? Font.Medium : Font.Normal }
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }
    background: Rectangle {
      radius: 7
      color: Qt.alpha(root.tokens.cyan, choice.selected ? 0.09 : choice.hovered ? 0.04 : 0)
      border.color: choice.activeFocus ? root.tokens.cyan : choice.selected ? Qt.alpha(root.tokens.cyan, 0.4) : root.tokens.border
    }
  }
  ColumnLayout {
    width: root.availableWidth
    spacing: 12
    Section {
      objectName: "captureSourceCard"
      title: "CAPTURE"
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Choice { objectName: "captureTask-shot"; text: "Screenshot"; selected: root.task === "shot"; enabled: !root.busy; onClicked: Data.CapturePreferences.selectTask("shot") }
        Choice { objectName: "captureTask-record"; text: "Video"; selected: root.task === "record"; enabled: !root.busy; onClicked: Data.CapturePreferences.selectTask("record") }
      }
      Caption { text: root.task === "shot" ? "What would you like to capture?" : "What would you like to record?"; color: root.tokens.text }
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Repeater {
          model: root.task === "shot"
            ? [{key: "monitor", label: "Screen"}, {key: "region", label: "Region"}, {key: "window", label: "Window"}]
            : [{key: "monitor", label: "Screen"}, {key: "region", label: "Region"}]
          Choice {
            id: sourceChoice
            required property var modelData
            objectName: "captureSource-" + modelData.key
            implicitHeight: 70
            enabled: !root.busy
            selected: root.mode === modelData.key
            text: modelData.label
            onClicked: Data.CapturePreferences.selectSource(modelData.key)
            contentItem: ColumnLayout {
              spacing: 6
              Components.CaptureGlyph { Layout.alignment: Qt.AlignHCenter; kind: sourceChoice.modelData.key; ink: sourceChoice.selected ? root.tokens.cyan : root.tokens.muted }
              Text { Layout.fillWidth: true; text: sourceChoice.text; horizontalAlignment: Text.AlignHCenter; color: sourceChoice.selected ? root.tokens.text : root.tokens.muted; font { family: root.tokens.font; pixelSize: 11 } }
            }
          }
        }
      }
      Caption { text: "Display to capture"; visible: root.mode === "monitor"; font { family: root.tokens.mono; pixelSize: 10 } }
      ComboBox {
        id: outputs
        objectName: "captureMonitorSelector"
        Layout.fillWidth: true
        implicitHeight: 38
        visible: root.mode === "monitor"
        enabled: !root.busy && count > 0
        model: Data.BrightnessData.outputNames
        currentIndex: Math.max(0, model.indexOf(Data.CapturePreferences.monitor))
        onActivated: index => Data.CapturePreferences.selectMonitor(model[index])
        displayText: count > 0 ? currentText : "No displays connected"
        Accessible.name: "Capture display"
        leftPadding: 12; rightPadding: 30
        contentItem: Text { text: outputs.displayText; color: root.tokens.text; font { family: root.tokens.mono; pixelSize: 11 } verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        indicator: Text { x: outputs.width - width - 12; anchors.verticalCenter: parent.verticalCenter; text: outputs.popup.visible ? "−" : "+"; color: root.tokens.cyan }
        background: Rectangle { radius: 7; color: root.tokens.surface; border.color: outputs.activeFocus ? root.tokens.cyan : root.tokens.border }
        delegate: ItemDelegate {
          id: monitorOption
          required property string modelData
          required property int index
          width: outputs.width - 2
          implicitHeight: 36
          highlighted: outputs.highlightedIndex === index
          contentItem: Text { text: monitorOption.modelData; color: root.tokens.text; font { family: root.tokens.mono; pixelSize: 11 } verticalAlignment: Text.AlignVCenter }
          background: Rectangle { radius: 5; color: monitorOption.highlighted ? Qt.alpha(root.tokens.cyan, 0.1) : "transparent" }
        }
        popup: Popup {
          y: outputs.height + 4; width: outputs.width; padding: 4
          implicitHeight: Math.min(200, monitorList.contentHeight + 8)
          background: Rectangle { radius: 8; color: root.tokens.surface; border.color: root.tokens.border }
          contentItem: ListView { id: monitorList; clip: true; implicitHeight: contentHeight; model: outputs.popup.visible ? outputs.delegateModel : null; currentIndex: outputs.highlightedIndex; ScrollIndicator.vertical: ScrollIndicator {} }
        }
      }
      Caption {
        text: root.mode === "window" ? "Capture the active window. The panel closes automatically."
          : root.mode === "region" ? root.task === "shot" ? "Drag anywhere to select an area. Escape cancels." : "Drag an area inside one display. Escape cancels."
          : "Capture the entire selected display. The panel hides automatically."
      }
      ColumnLayout {
        objectName: "captureAudioCard"
        Layout.fillWidth: true
        visible: root.task === "record"
        spacing: 8
        Caption { text: "Include audio"; color: root.tokens.text }
        GridLayout {
          Layout.fillWidth: true
          columns: 2; columnSpacing: 8; rowSpacing: 8
          Repeater {
            model: [{key: "none", label: "No audio"}, {key: "system", label: "System"}, {key: "microphone", label: "Microphone"}, {key: "both", label: "System + mic"}]
            Choice {
              required property var modelData
              objectName: "captureAudio-" + modelData.key
              text: modelData.label
              selected: root.audio === modelData.key
              enabled: !root.busy
              onClicked: Data.CapturePreferences.selectAudio(modelData.key)
            }
          }
        }
        Caption { text: root.audioSummary }
      }
      Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.tokens.border }
      Caption { text: root.statusLabel; visible: root.busy; color: root.tokens.alert }
      Text {
        visible: root.busy && Data.CaptureData.kind === "record"
        text: Math.floor(Data.CaptureData.duration / 60).toString().padStart(2, "0") + ":" + (Data.CaptureData.duration % 60).toString().padStart(2, "0")
        color: root.tokens.alert
        font { family: root.tokens.mono; pixelSize: 24 }
      }
      Choice {
        objectName: root.task === "shot" ? "takeScreenshot" : "startRecording"
        text: root.task === "shot" ? "Take screenshot" : "Start recording"
        selected: true
        implicitHeight: 42
        visible: !root.busy
        enabled: root.canCapture
        onClicked: root.start(root.task)
      }
      PanelButton {
        objectName: "stopCapture"
        tokens: root.tokens
        Layout.fillWidth: true
        text: Data.CaptureData.kind === "record" ? "Stop and save video" : "Cancel capture"
        destructive: true
        visible: root.busy
        onClicked: Data.CaptureData.stop()
      }
      Caption { text: root.task === "shot" ? "Saves a PNG to Pictures / Screenshots." : "Saves a video to Videos / ScreenRecordings."; visible: !root.busy; font.pixelSize: 10 }
      Caption { text: Data.CaptureData.error; color: root.tokens.alert; visible: text !== "" }
      ColumnLayout {
        Layout.fillWidth: true
        visible: root.lastResult !== "" && !root.busy
        spacing: 8
        Caption { text: "Saved · " + root.lastResult.split("/").pop(); color: root.tokens.cyan }
        RowLayout {
          Layout.fillWidth: true
          Choice { text: root.lastEntry && root.lastEntry.launchState === "opening" ? "Opening…" : "Open file"; enabled: !root.lastEntry || root.lastEntry.launchState !== "opening"; onClicked: Data.NotificationData.openFile(root.lastResult, false) }
          Choice { text: "Show in folder"; enabled: !root.lastEntry || root.lastEntry.launchState !== "opening"; onClicked: Data.NotificationData.openFile(root.lastResult, true) }
        }
        Caption { text: root.lastEntry ? root.lastEntry.launchMessage || "" : ""; visible: text !== ""; color: root.lastEntry && root.lastEntry.launchState === "error" ? root.tokens.alert : root.tokens.muted }
      }
    }
    Section {
      objectName: "displayBrightnessCard"
      title: "BRIGHTNESS"
      Repeater {
        model: Data.BrightnessData.monitorModel
        ColumnLayout {
          id: brightnessRow
          required property string name
          required property real percent
          required property bool available
          required property string reason
          Layout.fillWidth: true
          spacing: 6
          RowLayout {
            Layout.fillWidth: true
            Components.CaptureGlyph { kind: "monitor"; ink: brightnessRow.available ? root.tokens.cyan : root.tokens.muted }
            Caption { text: brightnessRow.name; color: root.tokens.text; font.weight: Font.Medium }
            Text { text: brightnessRow.available ? Math.round(brightnessSlider.value) + "%" : "Unavailable"; color: brightnessRow.available ? root.tokens.cyan : root.tokens.muted; font { family: root.tokens.mono; pixelSize: 11 } }
          }
          Slider {
            id: brightnessSlider
            objectName: "brightnessSlider-" + brightnessRow.name
            Layout.fillWidth: true
            from: 0; to: 100; stepSize: 1
            Binding {
              target: brightnessSlider; property: "value"
              value: Data.BrightnessData.requestedValues[brightnessRow.name] !== undefined ? Data.BrightnessData.requestedValues[brightnessRow.name] : brightnessRow.percent
              when: !brightnessSlider.pressed
              restoreMode: Binding.RestoreNone
            }
            Component.onDestruction: Data.BrightnessData.cancelAdjustment(brightnessRow.name)
            onPressedChanged: {
              if (pressed) Data.BrightnessData.beginAdjustment(brightnessRow.name);
              else Data.BrightnessData.endAdjustment(brightnessRow.name, value);
            }
            enabled: brightnessRow.available
            Accessible.name: "Brightness " + brightnessRow.name
            onMoved: Data.BrightnessData.setBrightness(brightnessRow.name, value)
            implicitHeight: 26
            background: Rectangle {
              x: brightnessSlider.leftPadding; y: (brightnessSlider.height - height) / 2
              width: brightnessSlider.availableWidth; height: 4; radius: 2
              color: root.tokens.border
              Rectangle { width: parent.width * brightnessSlider.visualPosition; height: parent.height; radius: 2; color: brightnessSlider.enabled ? root.tokens.cyan : root.tokens.muted }
            }
            handle: Rectangle {
              x: brightnessSlider.leftPadding + brightnessSlider.visualPosition * (brightnessSlider.availableWidth - width)
              y: (brightnessSlider.height - height) / 2
              width: 12; height: 12; radius: 6
              color: brightnessSlider.enabled ? root.tokens.cyan : root.tokens.muted
              border.width: brightnessSlider.activeFocus ? 2 : 0; border.color: root.tokens.text
            }
          }
          Caption { objectName: "brightnessFeedback-" + brightnessRow.name; text: brightnessRow.reason; visible: text !== ""; font.pixelSize: 10 }
        }
      }
      Caption { text: "No displays detected."; visible: Data.BrightnessData.monitors.length === 0 }
      Caption { text: Data.BrightnessData.error; color: root.tokens.alert; visible: text !== "" }
    }
  }
}
