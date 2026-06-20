#!/usr/bin/env bash
# In-container: build + install the effect, then run a VISIBLE nested kwin_wayland
# (a window on the host WSLg/Windows desktop) with the effect enabled and a couple of
# test windows to drag. Hold Shift while dragging a window to see the zone overlay,
# release to snap.
#
# Expects: WAYLAND_DISPLAY + XDG_RUNTIME_DIR pointing at the host (WSLg) wayland socket.
# Mounts: /opt/effect, /opt/hw, plus the WSLg runtime dir.
set -uo pipefail

if ! command -v kwin_wayland >/dev/null || ! command -v cmake >/dev/null; then
  echo "### installing deps (non-baked image) ###"
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq --no-install-recommends \
    cmake extra-cmake-modules g++ make kwin-dev qt6-base-dev qt6-base-dev-tools \
    qt6-declarative-dev libkf6coreaddons-dev libxkbcommon-dev \
    kwin-wayland xwayland xterm xfonts-base x11-utils libegl1 libegl-mesa0 libgles2 >/dev/null 2>&1
fi

cd /work || { echo "no /work"; exit 1; }
echo "### building the effect ###"
cmake -S /opt/effect -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release >cmake.log 2>&1 || { tail -20 cmake.log; exit 1; }
cmake --build build -j"$(nproc)" >make.log 2>&1 || { tail -30 make.log; exit 1; }
QTP=$(qtpaths6 --plugin-dir 2>/dev/null || echo /usr/lib/x86_64-linux-gnu/qt6/plugins)
mkdir -p "$QTP/kwin/effects/plugins"; cp build/fancyzones.so "$QTP/kwin/effects/plugins/"
echo "installed effect -> $QTP/kwin/effects/plugins/"

# Enable the effect at startup (plugin id = fancyzones) and force compositing on.
mkdir -p /root/.config
printf '[Plugins]\nfancyzonesEnabled=true\n\n[Compositing]\nEnabled=true\n' > /root/.config/kwinrc

# WSL GPU libs (d3d12) if present, else mesa software GL.
export LD_LIBRARY_PATH=/usr/lib/wsl/lib:${LD_LIBRARY_PATH:-}
[ -e /dev/dxg ] || export LIBGL_ALWAYS_SOFTWARE=1
export KWIN_WAYLAND_NO_PERMISSION_CHECKS=1

# XWayland needs this socket dir (so the X11 test windows can map); session bus for KWin.
mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
eval "$(dbus-launch --sh-syntax)"; export DBUS_SESSION_BUS_ADDRESS

echo "### launching nested KWin (a window should open on your Windows desktop) ###"
echo "### inside it: hold Shift and drag a window -> zone overlay; release to snap. ###"
# No --virtual: with WAYLAND_DISPLAY set, kwin_wayland uses the nested wayland backend
# and opens a 1600x900 window in the host compositor (WSLg).
exec kwin_wayland --width 1600 --height 900 --xwayland --no-lockscreen /opt/hw/visual-apps.sh
