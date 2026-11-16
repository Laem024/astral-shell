pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
  id: host
  property var policy: null
  // These input-only surfaces consume the outside press on every output.
  // Holes preserve the panel, its controls and child popups.
  Variants {
    model: host.policy && host.policy.opened && host.policy.ownerScreen ? Quickshell.screens : []
    // qmllint disable uncreatable-type
    PanelWindow {
      id: shield
      required property var modelData
      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "astral-popup-dismiss"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {
        width: shield.width; height: shield.height
        Region {
          intersection: Intersection.Subtract
          x: host.policy.contentRect.x; y: host.policy.contentRect.y
          width: shield.modelData === host.policy.ownerScreen ? host.policy.contentRect.width : 0
          height: host.policy.contentRect.height
        }
        Region {
          intersection: Intersection.Subtract
          x: host.policy.controlRect.x; y: host.policy.controlRect.y
          width: shield.modelData === host.policy.ownerScreen ? host.policy.controlRect.width : 0
          height: host.policy.controlRect.height
        }
      }
      Component.onCompleted: host.policy.surfaces = host.policy.surfaces.concat([shield])
      Component.onDestruction: host.policy.surfaces = host.policy.surfaces.filter(s => s !== shield)
      MouseArea { anchors.fill: parent; onPressed: mouse => { mouse.accepted = true; host.policy.dismiss(); } }
    }
  }
}
