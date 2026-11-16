pragma Singleton
import QtQuick
import Quickshell

Singleton {
  readonly property date dateTime: clock.date

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
