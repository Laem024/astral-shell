pragma Singleton
import QtQuick
import Quickshell

// Only this coordinator knows peers. Closing a peer never starts its module.
Singleton {
  id: root
  function entry(id) {
    const module = SettingsData.value.modules.find(m => m.id === id);
    if (!module) return "";
    let path = module.path.startsWith("/") ? module.path : Quickshell.shellDir + "/" + module.path;
    return path.endsWith(".qml") ? path : path + "/shell.qml";
  }
  function dismiss(owner) {
    const task = transaction.createObject(root, {owner: owner}); task.next();
  }
  property Component transaction: Component {
    QtObject {
      id: task
      required property string owner
      property var peers: [
        {id:"astral-clipboard", target:"clipboard", method:"close"},
        {id:"astral-overview", target:"overview", method:"close"},
        {id:"astral-shortcuts", target:"shortcuts", method:"close"},
        {id:"astral-wallpaper", target:"wallpaper-carousel", method:"close"},
        {id:"astral-wallpaper", target:"wallpaper", method:"close"},
        {id:"astral-bar", target:"bar", method:"closePanels"},
        {id:"astral-launcher", target:"launcher", method:"close"},
        {id:"astral-session", target:"session", method:"close"}
      ]
      property int index: 0
      property Command request: Command { timeout: 2000 }
      function next() {
        if (index >= peers.length) { destroy(); return; }
        const peer = peers[index++], path = root.entry(peer.id);
        if (peer.id === owner || !path) { next(); return; }
        request.run(["qs", "ipc", "-p", path, "call", peer.target, peer.method], () => next());
      }
    }
  }
}
