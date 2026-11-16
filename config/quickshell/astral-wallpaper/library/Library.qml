import QtQuick
import "../../common" as Common
import "../Logic.js" as Logic

QtObject {
  id: root
  readonly property bool running: request.running
  property Common.Command request: Common.Command { timeout: 30000 }
  signal finished(int code, var entries, string error, string folder)
  function scan(folder) {
    if (!folder.startsWith("/") || folder.includes("\0")) { finished(1, [], "Invalid library folder.", folder); return; }
    const prefix = folder.replace(/\/+$/, "") + "/";
    request.run(["find", folder, "-type", "f", "-printf", "%P\\0%s\\0%T@\\0"], (code, output) => {
      const fields = output.split("\0"), entries = [];
      for (let i = 0; i + 2 < fields.length; i += 3) {
        const relative = fields[i], path = prefix + relative;
        if (Logic.kind(path)) entries.push({path: path, relative: relative, name: relative.split("/").pop(), size: fields[i+1], modified: fields[i+2], theme: Logic.classify(relative), kind: Logic.kind(path)});
      }
      entries.sort((a, b) => a.relative < b.relative ? -1 : a.relative > b.relative ? 1 : 0);
      finished(code, entries, code ? "Could not read the wallpaper library." : "", folder);
    });
  }
}
