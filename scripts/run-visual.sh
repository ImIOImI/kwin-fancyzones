#!/usr/bin/env bash
# Run kwin-fancyzones VISIBLY: a nested KWin window opens on your desktop (via WSLg
# on WSL2, or any Wayland session) with the effect loaded and test windows to drag.
# Inside the KWin window: hold Shift while dragging a window to see the zone overlay;
# release to snap. Close the window (or Ctrl-C here) to stop.
#
# Requires a Wayland display (WSLg sets WAYLAND_DISPLAY on Windows 11 WSL2).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${FZ_IMAGE:-kwin-fancyzones-test:dev}"

[ -n "${WAYLAND_DISPLAY:-}" ] || { echo "No WAYLAND_DISPLAY. This needs a Wayland session (WSLg on Windows 11 WSL2)."; exit 1; }

# WSLg keeps its sockets in /mnt/wslg/runtime-dir; fall back to XDG_RUNTIME_DIR.
HOST_RT="/mnt/wslg/runtime-dir"
[ -S "$HOST_RT/$WAYLAND_DISPLAY" ] || HOST_RT="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
[ -S "$HOST_RT/$WAYLAND_DISPLAY" ] || { echo "Couldn't find the wayland socket ($WAYLAND_DISPLAY) under $HOST_RT"; exit 1; }
echo "Using wayland socket: $HOST_RT/$WAYLAND_DISPLAY"

docker image inspect "$IMAGE" >/dev/null 2>&1 || "$REPO/scripts/build-effect-image.sh"

GPU=()
[ -e /dev/dxg ] && GPU=(--device /dev/dxg -v /usr/lib/wsl:/usr/lib/wsl:ro)

# Bind-mount only the host's wayland socket (as an absolute path) and give the
# container its own root-owned XDG_RUNTIME_DIR — otherwise KWin can't create its own
# compositor socket (the host socket would occupy the slot) and dbus-launch fails on
# the host-owned runtime dir.
exec docker run --rm -it --privileged \
  -e XDG_RUNTIME_DIR=/tmp/fzxdg -e "WAYLAND_DISPLAY=/wslg/$WAYLAND_DISPLAY" \
  -v "$HOST_RT/$WAYLAND_DISPLAY:/wslg/$WAYLAND_DISPLAY" \
  "${GPU[@]}" \
  -v "$REPO/effect:/opt/effect:ro" \
  -v "$REPO/scripts/harness-wayland:/opt/hw:ro" \
  --tmpfs /work:exec \
  "$IMAGE" bash /opt/hw/visual-session.sh
