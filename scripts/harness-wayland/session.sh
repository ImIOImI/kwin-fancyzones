#!/usr/bin/env bash
# Runs INSIDE the kwin_wayland session (KWin sets DISPLAY for its Xwayland and
# WAYLAND_DISPLAY). Launch a test window via Xwayland, then keep the session alive.
for _ in $(seq 1 50); do
  [ -n "${DISPLAY:-}" ] && xdpyinfo >/dev/null 2>&1 && break
  sleep 0.2
done
xterm -T fzwin -e "sleep 100000" >/dev/null 2>&1 &
exec sleep infinity
