#!/usr/bin/env bash
# Behavioral test of overlapping-zone snapping with the nearest-center rule.
#
#   Drop the cursor at (960,800) on a 1920x1080 screen. That point is inside BOTH:
#     - "middle" column : x=640 w=640 h=1080, center (960,540)
#     - "focus"  zone   : x=576 w=768 h=432,  center (960,810)   <- overlaps middle
#   Nearest-center wins, so the drop near focus's center (810) picks "focus", not
#   the full-height middle column. Proves overlap resolution (built-in tiling can't).
#
# Also captures the overlay mid-drag (overlay.png) and the result (snap.png).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

fail() { echo "SNAP TEST FAILED: $*" >&2; exit 1; }

fz_start_session
fz_load_script fancyzones >/dev/null
fz_is_loaded fancyzones || fail "script not loaded"

log "spawning test window 'snaptest'"
fz_spawn_window snaptest >/dev/null
wid=$(xdotool search --name "^snaptest$" | head -1)
[ -n "$wid" ] || fail "test window never appeared"
eval "$(xdotool getwindowgeometry --shell "$wid")"
log "before: $X,$Y ${WIDTH}x${HEIGHT}"
cx=$((X + WIDTH / 2)); cy=$((Y + HEIGHT / 2))

# Meta+drag toward the focus zone's center, capturing the overlay while held.
xdotool keydown super
xdotool mousemove "$cx" "$cy" mousedown 1
sleep 0.3
xdotool mousemove 960 800
sleep 0.5
fz_screenshot "$FZ_LOG_DIR/overlay.png" || log "overlay screenshot failed (non-fatal)"
xdotool mouseup 1
xdotool keyup super
sleep 0.5

eval "$(xdotool getwindowgeometry --shell "$wid")"
log "after:  $X,$Y ${WIDTH}x${HEIGHT}"
echo "----- [fancyzones] lines from kwin.log -----"
grep -i fancyzones "$FZ_LOG_DIR/kwin.log" || echo "(none captured)"
echo "--------------------------------------------"
fz_screenshot "$FZ_LOG_DIR/snap.png" || log "screenshot failed (non-fatal)"

# focus ~ w=768 h=432 ; middle ~ w=640 h=1080. Width in (700,850) AND height < 700
# uniquely identify focus (insets absorbed by tolerance).
[ "$WIDTH" -gt 700 ] && [ "$WIDTH" -lt 850 ] || fail "width $WIDTH not ~768 — expected the 'focus' zone"
[ "$HEIGHT" -lt 700 ] || fail "height $HEIGHT not ~432 — snapped to the full-height middle column instead of focus"

echo "SNAP TEST PASSED — window snapped to the overlapping 'focus' zone ($X,$Y ${WIDTH}x${HEIGHT})"
