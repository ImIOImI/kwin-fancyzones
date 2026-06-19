// kwin-fancyzones — KWin script (skeleton).
//
// At this milestone the goal is only to prove the headless test pipeline works
// end-to-end: the script loads into KWin, can enumerate windows, and can move
// one. The real feature — overlapping canvas zones with a drag-time snap overlay
// — builds on top of this in later milestones.

print("[fancyzones] script loaded");

// Plasma 6 exposes workspace.windowList(); older KWin used clientList().
function listWindows() {
    if (typeof workspace.windowList === "function") return workspace.windowList();
    if (typeof workspace.clientList === "function") return workspace.clientList();
    return workspace.stackingOrder || [];
}

// Demo: reposition the first normal window to a distinctive geometry. The smoke
// test asserts that this move happened.
function demoRepositionFirstWindow() {
    var wins = listWindows();
    print("[fancyzones] window count: " + wins.length);
    for (var i = 0; i < wins.length; i++) {
        var w = wins[i];
        if (w && w.normalWindow) {
            print("[fancyzones] repositioning: " + w.caption);
            w.frameGeometry = { x: 700, y: 400, width: 600, height: 400 };
            return true;
        }
    }
    print("[fancyzones] no normal window found to reposition");
    return false;
}

if (typeof workspace.windowAdded !== "undefined") {
    workspace.windowAdded.connect(function (w) {
        print("[fancyzones] window added: " + (w ? w.caption : "?"));
    });
}

demoRepositionFirstWindow();
