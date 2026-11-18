import QtQuick
import QtTest
import "../../config/quickshell/common/ModuleLogic.js" as Modules
import "../../config/quickshell/common/Defaults.js" as Defaults
import "../../config/quickshell/common/Validation.js" as Validation
import "../../config/quickshell/astral-bar/data/BrightnessLogic.js" as Brightness
import "../../config/quickshell/astral-bar/data/CaptureLogic.js" as Capture
import "../../config/quickshell/astral-bar/data/WindowLogic.js" as WindowLogic

TestCase {
  name: "MigrationLogic"
  function copy(value) { return JSON.parse(JSON.stringify(value)); }
  function rejects(action) { let rejected = false; try { action(); } catch (_) { rejected = true; } verify(rejected); }
  function test_force_close_target() {
    // A different window may have focus by the time the client query finishes.
    const clients = JSON.stringify([{address: "0xbb", pid: 202, focusHistoryID: 0},
      {address: "0xaa", pid: 101, focusHistoryID: 1}]);
    compare(WindowLogic.pidForAddress(clients, "aa"), 101);
    compare(WindowLogic.pidForAddress(clients, "0xaa"), 101);
    // A disappeared target must never fall back to the newly focused client.
    compare(WindowLogic.pidForAddress(clients, "0xcc"), 0);
    compare(WindowLogic.pidForAddress(clients, ""), 0);
    compare(WindowLogic.pidForAddress("{}", "aa"), 0);
    compare(WindowLogic.pidForAddress("{broken", "aa"), 0);
    for (const pid of [-1, 0, 1, 12.5, "101", null])
      compare(WindowLogic.pidForAddress(JSON.stringify([{address: "0xaa", pid: pid}]), "aa"), 0);
  }
  function test_settings() {
    compare(Validation.parse(JSON.stringify(Defaults.common), "common").modules.length, 11);
    compare(Validation.parse(JSON.stringify(Defaults.bar), "bar").position, "top");
    let value = copy(Defaults.common);
    value.providers.lock = ["/home/user/a locker", "--option", "literal;$(test)"];
    value.modules.push({id: "external", path: "/home/user/path with spaces/main.qml", enabled: true, autostart: false});
    compare(Validation.parse(JSON.stringify(value), "common").modules[1].path, value.modules[1].path);
    value.modules.push(copy(value.modules[1])); rejects(() => Validation.parse(JSON.stringify(value), "common"));
    value = copy(Defaults.common); value.providers.lock = "sh -c locker"; rejects(() => Validation.parse(JSON.stringify(value), "common"));
    value = copy(Defaults.common); value.scale = 0; rejects(() => Validation.parse(JSON.stringify(value), "common"));
    value = copy(Defaults.common); value.idle.lockSeconds = 0; rejects(() => Validation.parse(JSON.stringify(value), "common"));
    value = copy(Defaults.common); value.idle.screenOffSeconds = 1; rejects(() => Validation.parse(JSON.stringify(value), "common"));
    value = copy(Defaults.common); value.lockScreen.showMusic = "yes"; rejects(() => Validation.parse(JSON.stringify(value), "common"));
    value = copy(Defaults.bar); value.position = "diagonal"; rejects(() => Validation.parse(JSON.stringify(value), "bar"));
    value = copy(Defaults.bar); value.components.audio = 42; rejects(() => Validation.parse(JSON.stringify(value), "bar"));
    rejects(() => Validation.parse("{", "bar"));
  }
  function test_registry() {
    const registry = [{id:"bar",path:"bar",enabled:true,autostart:true}, {id:"manual",path:"/a path/main.qml",enabled:true,autostart:false}, {id:"disabled",path:"disabled",enabled:false,autostart:true}, {id:"file",path:"/a path/main.qml",enabled:true,autostart:true}];
    const entries = Modules.entries(registry, "/root with spaces");
    compare(entries.length, 2);
    compare(entries[0].entry, "/root with spaces/bar/shell.qml");
    compare(entries[1].entry, "/a path/main.qml");
  }
  function test_brightness() {
    const monitors = [{name:"eDP-1"},{name:"DP-1"}];
    compare(Brightness.resolve("eDP-1", monitors, ["intel_backlight"], []).device, "intel_backlight");
    compare(Brightness.resolve("eDP-1", monitors, ["a", "b"], []).device, "");
    compare(Brightness.resolve("eDP-1", [{name:"eDP-1"},{name:"DSI-1"}], ["a"], []).device, "");
    compare(Brightness.resolve("DP-1", monitors, [], ["/sys/class/drm/card1-DP-1"]).connector, "/sys/class/drm/card1-DP-1");
    compare(Brightness.resolve("DP-1", monitors, [], ["/sys/class/drm/card1-DP-1", "/sys/class/drm/card2-DP-1"]).device, "");
    compare(Brightness.percentage("50", "200"), 25);
    rejects(() => Brightness.percentage("50", "0"));
  }
  function test_capture() {
    const monitors = [{name:"DP-1",x:0,y:0,width:1920,height:1080,scale:1,transform:0}, {name:"DP-2",x:1920,y:0,width:1080,height:1920,scale:2,transform:1}];
    compare(Capture.outputForRegion(Capture.region("10,20 100x200"), monitors), "DP-1");
    compare(Capture.outputForRegion(Capture.region("1920,0 900x500"), monitors), "DP-2");
    rejects(() => Capture.outputForRegion(Capture.region("1900,0 100x100"), monitors));
    rejects(() => Capture.region("0,0 0x100"));
    rejects(() => Capture.request({kind:"record",mode:"window",audio:"none",monitor:"DP-1"}));
    compare(Capture.bluetoothCard("bluez_input.41:42:FF:98:CD:17"), "bluez_card.41_42_FF_98_CD_17");
    compare(Capture.bluetoothCard("bluez_output.41_42_FF_98_CD_17.1"), "bluez_card.41_42_FF_98_CD_17");
  }
}
