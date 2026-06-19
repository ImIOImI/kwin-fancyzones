#!/usr/bin/env bash
# Lightweight smoke check: the session comes up and the KWin script loads.
# Verified via the Scripting D-Bus isScriptLoaded() so it doesn't depend on log
# capture. Behavioral snapping is covered by run-snap-test.sh.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$DIR/lib.sh"

fail() { echo "SMOKE TEST FAILED: $*" >&2; exit 1; }

fz_start_session
fz_load_script fancyzones >/dev/null
sleep 1

echo "----- [fancyzones] lines from kwin.log -----"
grep -i fancyzones "$FZ_LOG_DIR/kwin.log" || echo "(none captured)"
echo "----- QML/script errors (if any) -----"
grep -iE "\.qml|error|warning|undefined" "$FZ_LOG_DIR/kwin.log" | grep -vi "kwin_core" | head -20 || true
echo "--------------------------------------------"

fz_is_loaded fancyzones || fail "isScriptLoaded(fancyzones) is false — script failed to load (see $FZ_LOG_DIR/kwin.log)"

echo "SMOKE TEST PASSED — KWin is up and the 'fancyzones' script is loaded"
