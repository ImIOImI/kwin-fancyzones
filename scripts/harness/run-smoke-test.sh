#!/usr/bin/env bash
# End-to-end smoke test of the headless pipeline:
#   Xvfb -> kwin_x11 -> load KWin script -> script repositions a real window.
# Passes if the mounted script actually moves the test window (behavioral check,
# independent of whether print() output is captured in the log).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

fail() { echo "SMOKE TEST FAILED: $*" >&2; exit 1; }

fz_start_session

[ -f "$FZ_SRC/contents/code/main.js" ] || fail "no KWin script mounted at $FZ_SRC/contents/code/main.js"

log "spawning test window 'fztest'"
fz_spawn_window "fztest" >/dev/null

geo_before=$(fz_window_geometry "fztest" || true)
log "geometry before: ${geo_before:-unknown}"
[ -n "$geo_before" ] || fail "test window never appeared"

fz_load_script "$FZ_SRC/contents/code/main.js" "fancyzones" >/dev/null
sleep 1.5

geo_after=$(fz_window_geometry "fztest" || true)
log "geometry after:  ${geo_after:-unknown}"

echo "----- [fancyzones] lines from kwin.log -----"
grep -i fancyzones "$FZ_LOG_DIR/kwin.log" || echo "(none captured — log routing varies; not fatal)"
echo "--------------------------------------------"

fz_screenshot "$FZ_LOG_DIR/smoke.png" || log "screenshot capture failed (non-fatal)"

[ -n "$geo_after" ] || fail "test window disappeared after loading script"
if [ "$geo_before" = "$geo_after" ]; then
  fail "window did not move (script loaded but had no effect). See $FZ_LOG_DIR/kwin.log"
fi

echo "SMOKE TEST PASSED — script loaded and repositioned the window ($geo_before -> $geo_after)"
