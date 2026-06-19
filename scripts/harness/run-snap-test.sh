#!/usr/bin/env bash
# Behavioral test of overlapping-zone snapping:
#   Drag a window so the cursor finishes at screen center (960,540 on 1920x1080).
#   That point is inside BOTH the full-height "middle" column and the smaller
#   "focus" zone. The smallest-zone-wins rule must pick "focus", proving overlap
#   resolution works (the thing built-in tiling can't do).
#
#   focus zone  ~ x=480 w=960   <- expected
#   middle col  ~ x=640 w=640
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

fail() { echo "SNAP TEST FAILED: $*" >&2; exit 1; }

fz_start_session
[ -f "$FZ_SRC/contents/code/main.js" ] || fail "no KWin script at $FZ_SRC/contents/code/main.js"
fz_load_script "$FZ_SRC/contents/code/main.js" fancyzones >/dev/null

log "spawning test window 'snaptest'"
fz_spawn_window snaptest >/dev/null
wid=$(xdotool search --name "^snaptest$" | head -1)
[ -n "$wid" ] || fail "test window never appeared"
eval "$(xdotool getwindowgeometry --shell "$wid")"
log "before: $X,$Y ${WIDTH}x${HEIGHT}"
cx=$((X + WIDTH / 2)); cy=$((Y + HEIGHT / 2))

# Drag to the screen center so the drop lands in the overlap of middle + focus.
fz_meta_drag "$cx" "$cy" 960 540

eval "$(xdotool getwindowgeometry --shell "$wid")"
log "after:  $X,$Y ${WIDTH}x${HEIGHT}"
echo "----- [fancyzones] lines from kwin.log -----"
grep -i fancyzones "$FZ_LOG_DIR/kwin.log" || echo "(none captured)"
echo "--------------------------------------------"
fz_screenshot "$FZ_LOG_DIR/snap.png" || log "screenshot failed (non-fatal)"

# Width discriminates focus (~960) from the middle column (~640); x discriminates
# focus (~480) from middle (~640). Tolerances absorb window-decoration insets.
[ "$WIDTH" -gt 800 ] || fail "width $WIDTH not ~960 — snapped to middle column or not at all"
[ "$X" -lt 600 ]     || fail "x $X not ~480 — did not pick the overlapping 'focus' zone"

echo "SNAP TEST PASSED — window snapped to the overlapping 'focus' zone ($X,$Y ${WIDTH}x${HEIGHT})"
