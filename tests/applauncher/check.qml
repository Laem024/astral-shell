import QtQuick
import QtQuick.Window
import Quickshell
import "../../config/quickshell/astral-launcher" as Launcher
import "../../config/quickshell/astral-launcher/Logic.js" as Logic
import "../../config/quickshell/common" as Common

Scope {
  id: root
  property int stage: 0
  property int ticks: 0
  function check(value, message) { if (!value) { console.error("LAUNCHER_FAIL: " + message); Qt.quit(); } }
  QtObject { id: settings; property var value: Common.SettingsData.value }
  Common.Theme { id: theme; settings: settings }
  Launcher.LauncherService { id: service; settings: settings; onAccepted: root.stage++ }
  Window {
    visible: true; width: 820; height: 560
    Launcher.LauncherContent { id: content; anchors.fill: parent; service: service; tokens: theme }
  }
  Timer {
    interval: 100; repeat: true; running: true
    onTriggered: {
      if (++root.ticks > 80) { root.check(false, "timeout stage " + root.stage); return; }
      if (!service.ready || service.entries.length < 5) return;
      if (root.stage === 0) {
        const entries = service.entries;
        root.check(entries.some(e => e.name === "Native Astral"), "native entry");
        root.check(entries.some(e => e.name === "Flatpak Astral"), "Flatpak entry");
        root.check(entries.some(e => e.name === "AppImage Astral"), "AppImage entry");
        root.check(entries.some(e => e.name === "Steam Astral"), "Steam entry");
        root.check(!entries.some(e => e.name.includes("Hidden")), "hidden entries excluded");
        root.check(!entries.some(e => e.name === "Overridden"), "XDG precedence");
        const catalog = [{id:"one", name:"Café"}, {id:"two",name:"Cafeteria"}, {id:"three",name:"My cafe"}, {id:"four",name:"Café"}];
        const state = Logic.emptyState();
        root.check(Logic.select(catalog,state,"Favorites","CAFE").map(e=>e.id).join() === "four,one,two,three", "accent search, ranks, duplicates, global search");
        let s = Logic.toggle(state,"one.desktop");
        s = Logic.record(s,"two.desktop",100); s = Logic.record(s,"three.desktop",200);
        root.check(Logic.select(catalog,s,"Home","").map(e=>e.id).join() === "one,three,two", "home ordering");
        s = Logic.record(s,"two.desktop",50);
        root.check(Logic.frequent(catalog,s)[0].id === "two", "frequency count ordering");
        s = Logic.toggle(s,"retired.desktop");
        root.check(Logic.favorites(catalog,s).length === 1 && s.favorites.length === 2, "retain removed entries");
        root.check(Logic.toggle(s,"one.desktop").favorites.length === 1,"unpin");
        const many = Array.from({length:20}, (_,i)=>({id:"entry" + i,name:"Entry " + i}));
        let manyState = Logic.emptyState();
        many.forEach(e => { manyState = Logic.record(manyState,Logic.identity(e),100); });
        root.check(Logic.select(many,manyState,"Home","").length === 12,"home frequent limit");
        let invalid = false;
        try { Logic.parseState('{"version":1,"favorites":[],"usage":{"bad":{"count":-1,"last":0}}}'); } catch(e) { invalid = true; }
        root.check(invalid,"invalid usage");
        root.check(service.warning.length > 0,"invalid JSON warning");
        settings.value.applications.terminal = ["astral-test-terminal"];
        service.pin(entries.find(e=>Logic.identity(e) === "native.desktop"));
        content.reset();
        root.stage = 1;
        service.launch({id:"fail",runInTerminal:false});
      } else if (root.stage === 1 && !service.pending) {
        root.check(service.error.length > 0,"launch failure remains visible");
        root.check(service.error.includes("request rejected"),"service diagnostic preserved");
        root.check(!service.state.usage["fail.desktop"],"failure not counted");
        root.stage = 2;
        service.launch({id:"native",runInTerminal:false});
        service.launch({id:"native",runInTerminal:false}); // A pending duplicate is ignored.
      } else if (root.stage === 3 && !service.pending) {
        root.check(service.state.usage["native.desktop"].count === 1,"accepted request counted");
        root.stage = 4;
        service.launch({id:"terminal",runInTerminal:true,workingDirectory:Quickshell.env("ASTRAL_TEST_DIR") + "/working dir",command:["printf", "a b", "$(touch INJECTED)", "; touch INJECTED", "'quoted'"]});
      } else if (root.stage === 5 && !service.pending) {
        root.check(service.state.usage["terminal.desktop"].count === 1,"terminal accepted");
        root.stage = 6;
        service.launch({id:"bad-terminal",runInTerminal:true,workingDirectory:"/does/not/exist",command:["true"]});
      } else if (root.stage === 6 && !service.pending) {
        root.check(service.error.length > 0,"invalid directory rejected");
        root.stage = 7;
        settings.value.mode = "light"; settings.value.scale = 1.5;
        content.width = 360; content.height = 300;
      } else if (root.stage === 7) {
        settings.value.applications.terminal = ["astral-missing-terminal"];
        root.stage = 8;
        service.launch({id:"missing-terminal",runInTerminal:true,workingDirectory:"",command:["true"]});
      } else if (root.stage === 8 && !service.pending && !service.dirty) {
        root.check(service.error.length > 0 && !service.state.usage["missing-terminal.desktop"], "missing terminal rejected");
        console.log("LAUNCHER_PASS (catalog, logic, state, launch, content)"); Qt.quit();
      }
    }
  }
}
