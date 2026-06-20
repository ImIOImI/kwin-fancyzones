// kwin-fancyzones overlay (rendered by the C++ effect via QuickSceneEffect).
// Draws the zone layout. v0.5 step 1-2: just render + show/hide; live highlight and
// snapping come next. Zones mirror the approved mockup (3-column grid + a lower-center
// "focus" zone that overlaps the middle column).
import QtQuick

Item {
    id: root
    // QuickSceneView sizes this root item to the screen.

    property var zones: [
        { "name": "left",   "x": 0,     "y": 0,  "w": 33.34, "h": 100 },
        { "name": "middle", "x": 33.33, "y": 0,  "w": 33.34, "h": 100 },
        { "name": "right",  "x": 66.66, "y": 0,  "w": 33.34, "h": 100 },
        { "name": "focus",  "x": 30,    "y": 55, "w": 40,    "h": 40  }
    ]

    Repeater {
        model: root.zones
        Rectangle {
            x: Math.round(modelData.x / 100 * root.width)
            y: Math.round(modelData.y / 100 * root.height)
            width: Math.round(modelData.w / 100 * root.width)
            height: Math.round(modelData.h / 100 * root.height)
            radius: 12
            color: "#221d99f3"
            border.color: "#3daee9"
            border.width: 2
            Text {
                anchors.centerIn: parent
                text: modelData.name
                color: "white"
                font.pixelSize: 24
            }
        }
    }

    Component.onCompleted: console.log("[overlay] loaded size=" + width + "x" + height + " zones=" + zones.length)

    // Headless verification: once rendered, grab the overlay to a PNG.
    Timer {
        interval: 300
        running: true
        repeat: false
        onTriggered: root.grabToImage(function (res) {
            if (res) { res.saveToFile("/logs/overlay.png"); console.log("[overlay] screenshot saved"); }
            else { console.log("[overlay] grabToImage failed"); }
        })
    }
}
