#!/usr/bin/env bash
# Container entrypoint: prepare runtime dirs, then dispatch on the first argument.
set -euo pipefail

mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

case "${1:-test}" in
  smoke)   exec /opt/fz/harness/run-smoke-test.sh ;;
  snap)    exec /opt/fz/harness/run-snap-test.sh ;;
  test)    /opt/fz/harness/run-smoke-test.sh && exec /opt/fz/harness/run-snap-test.sh ;;
  session) exec /opt/fz/harness/start-session.sh --hold ;;
  shell)   exec bash ;;
  *)       exec "$@" ;;
esac
