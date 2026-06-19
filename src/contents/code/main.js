// kwin-fancyzones — v0.1 core snapping.
//
// Zones are expressed as percentages of the screen work area and MAY OVERLAP —
// that's the whole point, and what KDE's built-in recursive-split tiling can't do.
// When an interactive window move finishes, the window snaps to the zone under the
// cursor. When zones overlap, the SMALLEST zone containing the cursor wins, so a
// small zone stacked on top of a big one stays reachable.
//
// NOTE (v0.1): every drag snaps (no modifier gate yet) and there's no drag-time
// overlay. Both land in the next milestone — they're the interactive/visual layer,
// whereas this file is the snapping mechanic, which is what we can test headlessly.

var DEBUG = true;
function dbg(m) { if (DEBUG) print("[fancyzones] " + m); }

// Zone layout, percent of work area. The "focus" zone deliberately overlaps the
// middle column so overlap resolution is exercised.
var ZONES = [
    { name: "left",   x: 0,     y: 0,  width: 33.34, height: 100 },
    { name: "middle", x: 33.33, y: 0,  width: 33.34, height: 100 },
    { name: "right",  x: 66.66, y: 0,  width: 33.34, height: 100 },
    { name: "focus",  x: 25,    y: 20, width: 50,    height: 60  }
];

// Resolve the percent-based ZONES into pixel rects on the screen this client is on.
function zoneRects(client) {
    var screen = client.output || workspace.activeScreen;
    var area = workspace.clientArea(KWin.FullScreenArea, screen, workspace.currentDesktop);
    var rects = [];
    for (var i = 0; i < ZONES.length; i++) {
        var z = ZONES[i];
        rects.push({
            name: z.name,
            x: Math.round(area.x + (z.x / 100) * area.width),
            y: Math.round(area.y + (z.y / 100) * area.height),
            width: Math.round((z.width / 100) * area.width),
            height: Math.round((z.height / 100) * area.height)
        });
    }
    return rects;
}

function contains(r, x, y) {
    return x >= r.x && x < r.x + r.width && y >= r.y && y < r.y + r.height;
}
function rectArea(r) { return r.width * r.height; }

// Overlap resolution: among zones containing (x,y), pick the smallest.
function pickZone(rects, x, y) {
    var best = null;
    for (var i = 0; i < rects.length; i++) {
        if (contains(rects[i], x, y) && (best === null || rectArea(rects[i]) < rectArea(best))) {
            best = rects[i];
        }
    }
    return best;
}

function snap(client) {
    if (!client || !client.normalWindow) return;
    var c = workspace.cursorPos;
    var zone = pickZone(zoneRects(client), c.x, c.y);
    if (!zone) { dbg("no zone under cursor " + c.x + "," + c.y); return; }
    dbg("snapping '" + client.caption + "' to zone '" + zone.name + "' [" +
        zone.x + "," + zone.y + " " + zone.width + "x" + zone.height + "]");
    client.frameGeometry = { x: zone.x, y: zone.y, width: zone.width, height: zone.height };
}

function hook(client) {
    if (!client || !client.normalWindow) return;
    try {
        client.interactiveMoveResizeFinished.connect(function () { snap(client); });
    } catch (e) {
        dbg("could not hook '" + client.caption + "': " + e);
    }
}

function hookAll() {
    var wins = workspace.windowList ? workspace.windowList() : workspace.stackingOrder;
    for (var i = 0; i < wins.length; i++) hook(wins[i]);
    dbg("hooked " + wins.length + " existing window(s)");
}

workspace.windowAdded.connect(hook);
hookAll();
dbg("loaded with " + ZONES.length + " zones");
