import QtQuick
import Quickshell

Scope {
    // Eagerly create the service even when the dashboard has never been opened.
    Component.onCompleted: TimerService.tick()
}
