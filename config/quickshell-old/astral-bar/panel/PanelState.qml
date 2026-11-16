import QtQuick

QtObject {
  property string destination: ""
  property var owner: null
  property var anchor: null
  property bool tray: false
  property bool windowMenu: false
  // Update the target, the tray flag and the anchor before handing the panel to
  // the monitor. Otherwise the surface can turn invisible mid-switch, and its
  // visibility handler clears the anchor; the popup then falls back to the
  // centre of the bar instead of staying under its button.
  function toggle(target: string, monitor: var, control: var): void {
    if (!tray && !windowMenu && destination === target && owner === monitor) { close(); return; }
    anchor = control; destination = target; tray = false; windowMenu = false; owner = monitor;
  }
  function openTray(monitor: var): void { tray = true; windowMenu = false; destination = ""; owner = monitor; }
  // The window menu shares the panel surface and its focus grab. Raise its flag
  // before clearing the central destination: the surface must not become
  // invisible mid-switch, because the visibility handler would close the menu
  // and drop the fresh anchor, leaving it at the centre of the bar.
  function toggleWindowMenu(monitor: var, control: var): void {
    if (windowMenu && owner === monitor) { close(); return; }
    anchor = control; windowMenu = true; tray = false; destination = ""; owner = monitor;
  }
  // Hide first: once the owner is cleared the popup is already hidden, so the
  // remaining resets cannot make the surface flash at its fallback position.
  function close(): void { owner = null; destination = ""; tray = false; windowMenu = false; anchor = null; }
}
