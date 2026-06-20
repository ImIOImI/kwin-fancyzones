// Test setup helper (KWin declarativescript): positions the test window to a known
// rect so the effect harness can drive a move from a predictable point without
// querying Wayland geometry. Not part of the shipped product.
import QtQuick
import org.kde.kwin

Item {
    function place(w) {
        if (!w || !w.normalWindow) {
            return;
        }
        // Large + roughly centered so small test drags keep the cursor over it.
        w.frameGeometry = Qt.rect(100, 100, 1700, 880);
        console.log("[setup] positioned '" + w.caption + "' to 100,100 1700x880");
    }

    Component.onCompleted: {
        for (var i = 0; i < Workspace.stackingOrder.length; i++) {
            place(Workspace.stackingOrder[i]);
        }
        Workspace.windowAdded.connect(place);
        console.log("[setup] ready");
    }
}
