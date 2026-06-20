// kwin-fancyzones overlay (rendered by the C++ effect via QuickSceneEffect).
// Draws the zone layout and highlights the active zone (index pushed from C++ as the
// `highlighted` property). Layout mirrors the approved mockup: 3-column grid + a
// lower-center "focus" zone overlapping the middle column.
import QtQuick

Item {
    id: root
    // QuickSceneView sizes this root item to the screen.

    // Pushed live from the C++ effect (nearest-center zone under the cursor; -1 = none).
    property int highlighted: -1

    property var zones: [
        { "name": "left",   "x": 0,     "y": 0,  "w": 33.34, "h": 100 },
        { "name": "middle", "x": 33.33, "y": 0,  "w": 33.34, "h": 100 },
        { "name": "right",  "x": 66.66, "y": 0,  "w": 33.34, "h": 100 },
        { "name": "focus",  "x": 30,    "y": 55, "w": 40,    "h": 40  }
    ]

    Repeater {
        model: root.zones
        Rectangle {
            required property int index
            required property var modelData
            readonly property bool hot: index === root.highlighted

            x: Math.round(modelData.x / 100 * root.width)
            y: Math.round(modelData.y / 100 * root.height)
            width: Math.round(modelData.w / 100 * root.width)
            height: Math.round(modelData.h / 100 * root.height)
            radius: 12
            color: hot ? "#553daee9" : "#1a1d99f3"
            border.color: hot ? "#3daee9" : "#803daee9"
            border.width: hot ? 3 : 1
            Behavior on color { ColorAnimation { duration: 90 } }

            Text {
                anchors.centerIn: parent
                text: modelData.name
                color: "white"
                font.pixelSize: 24
                font.bold: parent.hot
                opacity: parent.hot ? 1.0 : 0.6
            }
        }
    }

    Component.onCompleted: console.log("[overlay] loaded size=" + width + "x" + height + " zones=" + zones.length)
}
