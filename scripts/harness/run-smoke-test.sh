#!/usr/bin/env bash
# Lightweight smoke check: the session comes up and the KWin script loads and runs
# without throwing (it logs "[fancyzones] loaded ..." on success). Behavioral
# snapping is covered by run-snap-test.sh.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

fail() { echo "SMOKE TEST FAILED: $*" >&2; exit 1; }

fz_start_session
[ -f "$FZ_SRC/contents/code/main.js" ] || fail "no KWin script mounted at $FZ_SRC/contents/code/main.js"

fz_load_script "$FZ_SRC/contents/code/main.js" fancyzones >/dev/null
sleep 1

echo "----- [fancyzones] lines from kwin.log -----"
grep -i fancyzones "$FZ_LOG_DIR/kwin.log" || echo "(none captured)"
echo "--------------------------------------------"

grep -qi "\[fancyzones\] loaded" "$FZ_LOG_DIR/kwin.log" \
  || fail "script did not report a clean load (see $FZ_LOG_DIR/kwin.log)"

echo "SMOKE TEST PASSED — KWin is up and the script loaded cleanly"
