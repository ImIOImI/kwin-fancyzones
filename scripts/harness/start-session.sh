#!/usr/bin/env bash
# Bring up a headless KWin session and load the mounted KWin script.
# Pass --hold to keep the container alive (tails kwin.log).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

fz_start_session

fz_load_script fancyzones || log "no script loaded"

log "session up. DISPLAY=$DISPLAY  logs=$FZ_LOG_DIR"
if [ "${1:-}" = "--hold" ]; then
  log "holding — tailing kwin.log (Ctrl-C to stop)"
  exec tail -f "$FZ_LOG_DIR/kwin.log"
fi
