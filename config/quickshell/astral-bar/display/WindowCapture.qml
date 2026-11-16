pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

// qmllint disable uncreatable-type
// A transparent, input-free render surface for grabToImage at native size.
PanelWindow {
  id: surface
  property var service: null
  visible: service !== null
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  implicitWidth: 1; implicitHeight: 1
  mask: Region {}
  Item {
    opacity: 0
    ScreencopyView {
      id: view
      width: sourceSize.width; height: sourceSize.height
      live: false
      captureSource: surface.service ? surface.service.window : null
      onStopped: if (surface.service && surface.service.busy) {
        surface.service.discard(); surface.service.fail("Window closed during capture.");
      }
      onHasContentChanged: if (hasContent && surface.service && surface.service.allocated) {
        const service = surface.service;
        const file = service.allocated;
        const accepted = view.grabToImage(result => {
          if (service.allocated !== file || !service.busy) return;
          if (!result.saveToFile(file)) { service.discard(); service.fail("Could not save window screenshot."); return; }
          service.verifyWindow(file);
        }, view.sourceSize);
        if (!accepted) { service.discard(); service.fail("Could not read the window frame."); }
      }
    }
  }
}
