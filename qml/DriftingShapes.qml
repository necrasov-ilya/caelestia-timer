// Inspired by Caelestia's Media background; uses the same Material shapes and palette.
pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root
    property bool animate: true
    readonly property var shapePool: [MaterialShape.Cookie4Sided, MaterialShape.Cookie9Sided,
        MaterialShape.Sunny, MaterialShape.SoftBurst, MaterialShape.Gem, MaterialShape.Pill, MaterialShape.Oval]
    clip: true

    Repeater {
        id: shapes
        model: 6
        delegate: MaterialShape {
            id: blob
            required property int index
            property real originX: ((index * 37 + 13) % 100) / 100
            property real originY: ((index * 61 + 9) % 100) / 100
            property real driftX: 0
            property real driftY: 0
            property real vx: (index % 2 ? -1 : 1) * (3 + index % 4)
            property real vy: (index % 3 ? 1 : -1) * (2 + index % 5)
            implicitSize: 44 + (index % 4) * 24
            x: originX * root.width + driftX - width / 2
            y: originY * root.height + driftY - height / 2
            shape: root.shapePool[index % root.shapePool.length]
            color: [Colours.palette.m3primaryContainer, Colours.palette.m3secondaryContainer,
                Colours.palette.m3tertiaryContainer][index % 3]
            opacity: Colours.light ? 0.3 : 0.16
            rotation: index * 29
            Behavior on color { CAnim {} }
        }
    }

    FrameAnimation {
        running: root.visible && root.animate && root.width > 0 && root.height > 0 && Tokens.anim.durations.scale > 0
        onTriggered: {
            const dt = Math.min(frameTime, 0.05);
            for (let i = 0; i < shapes.count; i++) {
                const blob = shapes.itemAt(i);
                if (!blob)
                    continue;
                blob.driftX += blob.vx * dt;
                blob.driftY += blob.vy * dt;
                blob.rotation += (i % 2 ? -4 : 5) * dt;
                if (blob.x > root.width + blob.width || blob.x < -blob.width)
                    blob.vx *= -1;
                if (blob.y > root.height + blob.height || blob.y < -blob.height)
                    blob.vy *= -1;
            }
        }
    }
}
