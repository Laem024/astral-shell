import QtQuick
import QtTest
import "../../config/quickshell/astral-bar/data/NetworkLogic.js" as Logic

TestCase {
  name: "NetworkLogic"
  function test_escapes() {
    compare(Logic.rows("wlan0:Caf\\:é\\\\ casa:80:WPA2\n")[0], ["wlan0", "Caf:é\\ casa", "80", "WPA2"]);
    compare(Logic.rows(" a :x::\n")[0], [" a ", "x", "", ""]);
  }
  function test_empty_properties() {
    compare(Logic.values("Open\n\nwlan0\n"), ["Open", "", "wlan0"]);
    compare(Logic.values("Open\n\n\n"), ["Open", "", ""]);
  }
  function test_grouping() {
    const result = Logic.networks("wlan0::Same:90:WPA2\nwlan0:*:Same:40:WPA2\nwlan0::Same:100:--\nwlan1::Same:70:WPA2\nwlan0:::50:WPA2\n");
    compare(result.length, 3);
    verify(result[0].active);
    compare(result[0].signal, 40);
    compare(result[1].security, "--");
    compare(result[2].device, "wlan1");
  }
  function test_security() {
    verify(Logic.compatible("WPA2 WPA3", "sae"));
    verify(Logic.compatible("WPA2 WPA3", "wpa-psk"));
    verify(!Logic.compatible("WPA3", "wpa-psk"));
    verify(!Logic.compatible("WPA2 802.1X", "wpa-psk"));
    verify(Logic.compatible("WPA2 802.1X", "wpa-eap"));
    verify(!Logic.compatible("--", "wpa-psk"));
  }
}
