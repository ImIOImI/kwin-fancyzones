// kwin-fancyzones overlay (rendered by the C++ effect).
// Both `zones` (the layout, from the config) and `highlighted` (the selected zone
// indices) are pushed from C++, so the config file is the single source of truth.
import QtQuick

Item {
    id: root
    // QuickSceneView sizes this root item to the screen.

    property var highlighted: []    // indices of the selected zone(s) (span); set by C++
    property var zones: []          // [{name,x,y,w,h}, …] in percent; set by the effect

    Repeater {
        model: root.zones
        Rectangle {
            required property int index
            required property var modelData
            readonly property bool hot: root.highlighted.indexOf(index) >= 0

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
