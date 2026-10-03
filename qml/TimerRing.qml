pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property real progress: 0
    property bool moving: false
    property real phase: 0
    readonly property real stroke: 7
    readonly property real amplitude: 0.55
    readonly property real radius: (Math.min(width, height) - stroke * (1 + 2 * amplitude)) / 2
    property real shownProgress: progress

    Behavior on shownProgress {
        Anim { type: Anim.DefaultEffects }
    }

    // Use the same compiled curve renderer as Caelestia's media seek bar.
    WavyLine {
        anchors.fill: parent
        anchors.margins: -root.stroke * root.amplitude
        lineWidth: root.stroke
        amplitudeMultiplier: root.amplitude
        pathType: WavyLine.Arc
        radius: root.radius
        startAngle: -90
        fullAngle: 360
        frequency: 14
        value: 1
        waveProgress: root.phase
        color: Colours.palette.m3secondaryContainer
        Behavior on color { CAnim {} }
    }

    WavyLine {
        anchors.fill: parent
        anchors.margins: -root.stroke * root.amplitude
        lineWidth: root.stroke
        amplitudeMultiplier: root.amplitude
        pathType: WavyLine.Arc
        radius: root.radius
        startAngle: -90
        fullAngle: 360
        frequency: 14
        value: Math.max(1 / 360, root.shownProgress)
        waveProgress: root.phase
        color: Colours.palette.m3primary
        Behavior on color { CAnim {} }
    }

    FrameAnimation {
        running: root.visible && root.moving && Tokens.anim.durations.scale > 0
        onTriggered: root.phase = (root.phase + Math.min(frameTime, 0.05) /
            (2.4 * Tokens.anim.durations.scale)) % 1
    }
}
