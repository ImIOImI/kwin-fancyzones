#!/usr/bin/env bash
# Runs inside the nested KWin session: launch a few draggable test windows, keep alive.
for _ in $(seq 1 50); do
  [ -n "${DISPLAY:-}" ] && xdpyinfo >/dev/null 2>&1 && break
  sleep 0.2
done
xterm -T "drag me (hold Shift)" -geometry 80x24+120+120 -e "sleep 100000" >/dev/null 2>&1 &
xterm -T "and me" -geometry 70x20+700+400 -e "sleep 100000" >/dev/null 2>&1 &
exec sleep infinity
