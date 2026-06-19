// kwin-fancyzones — v0.2: QML overlay + snapping.
//
// Converted from a plain-JS script to a QML `declarativescript` package so we can
// draw a drag-time overlay (KWin scripts can only manage windows; drawing needs
// QML). The overlay is a click-through PlasmaCore.Dialog shown while a window is
// being moved; the zone under the cursor lights up; on drop the window snaps to it.
//
// Overlap rule: among zones containing the cursor, the one whose CENTER is nearest
// the cursor wins (the user's chosen behavior).

import QtQuick
import org.kde.kwin
import org.kde.plasma.core as PlasmaCore

Item {
    id: root

    // Zones as percentages of the screen work area; overlap is allowed and the
    // point of the project. "focus" sits lower-center so nearest-center selection
    // is distinguishable from the full-height "middle" column.
    property var zones: [
        { "name": "left",   "x": 0,     "y": 0,  "width": 33.34, "height": 100 },
        { "name": "middle", "x": 33.33, "y": 0,  "width": 33.34, "height": 100 },
        { "name": "right",  "x": 66.66, "y": 0,  "width": 33.34, "height": 100 },
        { "name": "focus",  "x": 30,    "y": 55, "width": 40,    "height": 40  }
    ]

    property var area: ({ "x": 0, "y": 0, "width": 0, "height": 0 })
    property int highlighted: -1

    function refreshArea() {
        area = Workspace.clientArea(KWin.FullScreenArea, Workspace.activeScreen, Workspace.currentDesktop);
    }

    function zoneRect(z) {
        return Qt.rect(
            Math.round(area.x + (z.x / 100) * area.width),
            Math.round(area.y + (z.y / 100) * area.height),
            Math.round((z.width / 100) * area.width),
            Math.round((z.height / 100) * area.height));
    }

    // Nearest-center among zones containing (px,py). Returns zone index or -1.
    function pickZone(px, py) {
        var best = -1, bestDist = Infinity;
        for (var i = 0; i < zones.length; i++) {
            var r = zoneRect(zones[i]);
            if (px >= r.x && px < r.x + r.width && py >= r.y && py < r.y + r.height) {
                var cx = r.x + r.width / 2, cy = r.y + r.height / 2;
                var d = (cx - px) * (cx - px) + (cy - py) * (cy - py);
                if (d < bestDist) { bestDist = d; best = i; }
            }
        }
        return best;
    }

    function updateHighlight() {
        var c = Workspace.cursorPos;
        highlighted = pickZone(c.x, c.y);
    }

    // ---- drag-time overlay ----
    PlasmaCore.Dialog {
        id: overlay
        location: PlasmaCore.Types.Desktop
        type: PlasmaCore.Dialog.OnScreenDisplay
        backgroundHints: PlasmaCore.Types.NoBackground
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        hideOnWindowDeactivate: false
        outputOnly: true
        visible: false
        width: root.area.width
        height: root.area.height

        function showOverlay() {
            root.refreshArea();
            root.updateHighlight();
            overlay.setWidth(root.area.width);
            overlay.setHeight(root.area.height);
            overlay.visible = true;
        }
        function hideOverlay() {
            overlay.visible = false;
            root.highlighted = -1;
        }

        Item {
            id: canvas
            width: overlay.width
            height: overlay.height

            // Poll the cursor while visible to keep the highlight live during a drag.
            Timer {
                interval: 16; repeat: true; running: overlay.visible
                onTriggered: root.updateHighlight()
            }

            Repeater {
                model: root.zones
                Rectangle {
                    property rect r: root.zoneRect(modelData)
                    x: r.x - root.area.x
                    y: r.y - root.area.y
                    width: r.width
                    height: r.height
                    radius: 10
                    // Filled glow on the active zone (the user's chosen highlight style).
                    color: index === root.highlighted ? "#553daee9" : "#1a3daee9"
                    border.color: index === root.highlighted ? "#3daee9" : "#803daee9"
                    border.width: index === root.highlighted ? 3 : 1
                    Text {
                        anchors.centerIn: parent
                        text: modelData.name
                        color: "white"
                        font.pixelSize: 22
                        font.bold: index === root.highlighted
                        opacity: index === root.highlighted ? 1.0 : 0.5
                    }
                }
            }
        }
    }

    function snap(client) {
        var c = Workspace.cursorPos;
        var idx = root.pickZone(c.x, c.y);
        overlay.hideOverlay();
        if (idx < 0 || !client || !client.normalWindow) return;
        client.frameGeometry = root.zoneRect(root.zones[idx]);
        console.log("[fancyzones] snapped '" + client.caption + "' to zone '" + root.zones[idx].name + "'");
    }

    function hook(client) {
        if (!client || !client.normalWindow) return;
        client.interactiveMoveResizeStarted.connect(function () { overlay.showOverlay(); });
        client.interactiveMoveResizeFinished.connect(function () { root.snap(client); });
    }

    Component.onCompleted: {
        refreshArea();
        for (var i = 0; i < Workspace.stackingOrder.length; i++) hook(Workspace.stackingOrder[i]);
        Workspace.windowAdded.connect(hook);
        console.log("[fancyzones] loaded QML overlay with " + zones.length + " zones");
    }
}
