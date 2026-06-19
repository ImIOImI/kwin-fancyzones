#!/usr/bin/env bash
# Bring up a headless KWin session and load the mounted KWin script.
# Pass --hold to keep the container alive (tails kwin.log).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

fz_start_session

if [ -f "$FZ_SRC/contents/code/main.js" ]; then
  fz_load_script "$FZ_SRC/contents/code/main.js" "fancyzones" || true
else
  log "no KWin script at $FZ_SRC/contents/code/main.js (nothing to load)"
fi

log "session up. DISPLAY=$DISPLAY  logs=$FZ_LOG_DIR"
if [ "${1:-}" = "--hold" ]; then
  log "holding — tailing kwin.log (Ctrl-C to stop)"
  exec tail -f "$FZ_LOG_DIR/kwin.log"
fi
