pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
  PowerService { id: service }
  readonly property alias state: service
  // The setter is native; the displayed value comes from a separate daemon read.
  Connections {
    target: PowerProfiles
    function onProfileChanged() { service.refreshProfile(); }
  }
  Component.onCompleted: {
    service.performanceAvailable = Qt.binding(() => PowerProfiles.hasPerformanceProfile);
    service.setNativeProfile = function(name) {
      PowerProfiles.profile = name === "power-saver" ? PowerProfile.PowerSaver
        : name === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
    };
  }
}
