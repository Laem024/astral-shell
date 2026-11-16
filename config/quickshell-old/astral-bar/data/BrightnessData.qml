pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io

Singleton {
  id: root
  property var monitors: []
  property var outputNames: []
  property var requestedValues: ({})
  readonly property alias monitorModel: displayModel
  property string error: ""
  property var queued: ({})
  property var adjusting: ({})
  property string pending: ""
  property var externalReadings: ({})
  property double readStartedAt: 0
  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("../display/brightness.sh").toString().replace(/^file:\/\//, ""))
  ListModel { id: displayModel }
  function reconcile(rows): void {
    rows = rows.map(row => {
      const event = externalReadings[row.device];
      return row.backend === "backlight" && event && event.time >= readStartedAt
        ? Object.assign({}, row, {percent: event.percent}) : row;
    });
    // Preserve delegates and pointer grabs; only hotplug changes their identity.
    for (let i = displayModel.count - 1; i >= 0; i--)
      if (!rows.some(row => row.name === displayModel.get(i).name)) displayModel.remove(i);
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      let index = -1;
      for (let j = 0; j < displayModel.count; j++) if (displayModel.get(j).name === row.name) { index = j; break; }
      if (index < 0) displayModel.insert(i, row);
      else {
        if (index !== i) displayModel.move(index, i, 1);
        if (!adjusting[row.name]) displayModel.set(i, row);
      }
    }
    // Display selectors depend only on output names, not brightness readbacks.
    const names = rows.map(row => row.name);
    if (JSON.stringify(outputNames) !== JSON.stringify(names)) outputNames = names;
    if (JSON.stringify(monitors) !== JSON.stringify(rows)) monitors = rows;
  }
  function externalBrightness(device, percent): void {
    externalReadings = Object.assign({}, externalReadings, {[device]: {percent: percent, time: Date.now()}});
    for (let i = 0; i < displayModel.count; i++) {
      const row = displayModel.get(i);
      if (row.backend === "backlight" && row.device === device && row.available
          && !adjusting[row.name] && pending !== row.name && !(row.name in queued)) displayModel.setProperty(i, "percent", percent);
    }
    monitors = monitors.map(row => row.backend === "backlight" && row.device === device && row.available
      && !adjusting[row.name] && pending !== row.name && !(row.name in queued)
      ? Object.assign({}, row, {percent: percent}) : row);
  }
  Process {
    id: watcher
    command: ["bash", root.helper, "watch"]
    running: true
    stdout: SplitParser {
      onRead: line => {
        const fields = line.split("\t");
        const percent = Number(fields[2]);
        if (fields.length === 3 && fields[0] === "backlight" && fields[1] && Number.isFinite(percent) && percent >= 0 && percent <= 100)
          root.externalBrightness(fields[1], percent);
      }
    }
    onExited: watcherRetry.restart()
  }
  Timer { id: watcherRetry; interval: 1000; onTriggered: watcher.running = true }
  function beginAdjustment(name): void { adjusting[name] = true; }
  function cancelAdjustment(name): void { delete adjusting[name]; }
  function endAdjustment(name, value): void { delete adjusting[name]; setBrightness(name, value); }
  function setBrightness(name, value): void {
    const target = Math.max(0, Math.min(100, Math.round(value)));
    queued[name] = target;
    requestedValues = Object.assign({}, requestedValues, {[name]: target});
    next();
  }
  function next(): void {
    if (setter.running || reader.running || cadence.running) return;
    const names = Object.keys(queued);
    if (!names.length) return;
    pending = names[0];
    const value = queued[pending]; delete queued[pending];
    setter.command = ["bash", helper, "set", pending, String(value)];
    setter.running = true;
    cadence.start();
  }
  function refresh(): void {
    if (!reader.running && !setter.running && !Object.keys(queued).length && !Object.keys(adjusting).length) reader.running = true;
  }
  // Apply during continuous motion, coalescing newer values behind the writer.
  Timer { id: cadence; interval: 60; onTriggered: root.next() }
  Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: root.refresh() }
  Connections { target: Quickshell; function onScreensChanged() { if (!reader.running && !setter.running) reader.running = true; } }
  Process {
    id: reader
    command: ["bash", root.helper, "list"]
    onStarted: root.readStartedAt = Date.now()
    stdout: StdioCollector { id: output }
    stderr: StdioCollector { id: readError }
    onExited: (code, status) => {
      if (code === 0 && status === 0) {
        try { root.reconcile(JSON.parse(output.text)); root.error = ""; } catch (e) { root.error = String(e); }
      } else root.error = readError.text.trim();
      root.next();
    }
  }
  Process {
    id: setter
    stdout: StdioCollector { id: actual }
    stderr: StdioCollector { id: setError }
    onExited: (code, status) => {
      const name = root.pending;
      root.error = code !== 0 || status !== 0 ? setError.text.trim() || "Brightness update failed." : "";
      const value = Number(actual.text.trim());
      if (!root.error && actual.text.trim() !== "" && Number.isFinite(value) && value >= 0 && value <= 100) {
        for (let i = 0; i < displayModel.count; i++) if (displayModel.get(i).name === name) displayModel.setProperty(i, "percent", value);
        root.monitors = root.monitors.map(row => row.name === name ? Object.assign({}, row, {percent: value}) : row);
      }
      if (!(name in root.queued)) {
        const remaining = Object.assign({}, root.requestedValues); delete remaining[name];
        root.requestedValues = remaining;
      }
      root.pending = "";
      root.next();
    }
  }
}
