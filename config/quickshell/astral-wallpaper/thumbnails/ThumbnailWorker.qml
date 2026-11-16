import QtQuick
import Quickshell
import "../../common" as Common

QtObject {
  id: root
  required property string directory
  property bool busy: false
  property string source: ""
  property string target: ""
  property string temporary: ""
  signal finished(string key, string path)
  property Common.Command request: Common.Command { timeout: 22000 }
  function end(path) {
    const key = source;
    request.run(["rm", "-f", "--", temporary], () => { busy = false; finished(key, path); });
  }
  function start(path) {
    busy = true; source = path;
    request.run(["stat", "--printf=%s:%y", "--", path], (code, metadata) => {
      if (code !== 0) { busy = false; finished(path, ""); return; }
      target = directory + "/" + Qt.md5(path + "\0" + metadata) + ".jpg";
      temporary = target + ".part-" + Quickshell.instanceId;
      request.run(["test", "-s", target], code => {
        if (code === 0) { busy = false; finished(path, target); return; }
        request.run(["ffmpeg", "-v", "error", "-nostdin", "-i", path, "-frames:v", "1", "-vf", "scale=384:216:force_original_aspect_ratio=increase,crop=384:216", "-f", "image2", "-c:v", "mjpeg", "-threads", "1", "-y", temporary], code => {
          if (code !== 0) { end(""); return; }
          request.run(["chmod", "600", "--", temporary], code => {
            if (code !== 0) { end(""); return; }
            request.run(["mv", "-f", "--", temporary, target], code => end(code === 0 ? target : ""));
          });
        });
      });
    });
  }
}
