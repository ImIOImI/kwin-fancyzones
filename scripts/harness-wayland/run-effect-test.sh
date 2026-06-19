#!/usr/bin/env bash
# In-container: build the C++ KWin effect + the fake_input client, load the effect
# into a headless kwin_wayland session, inject a Shift+pointer sequence, and assert
# the effect observed the Shift modifier LIVE — the capability a KWin script lacks.
#
# Must run in a PRIVILEGED container: kwin_wayland needs elevated caps, and KWin only
# advertises the privileged fake_input protocol with KWIN_WAYLAND_NO_PERMISSION_CHECKS.
#
# Expects mounts: /opt/effect (repo effect/), /opt/hw (this dir), /logs (output).
set -uo pipefail
fail() { echo "EFFECT TEST FAILED: $*" >&2; exit 1; }

if ! command -v kwin_wayland >/dev/null || ! command -v cmake >/dev/null || ! command -v wayland-scanner >/dev/null; then
  echo "### installing build + wayland deps (first run is slow) ###"
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq --no-install-recommends \
    cmake extra-cmake-modules g++ make \
    kwin-dev qt6-base-dev qt6-base-dev-tools qt6-declarative-dev \
    libkf6coreaddons-dev libxkbcommon-dev \
    kwin-wayland libegl1 libegl-mesa0 libgles2 \
    libwayland-dev libwayland-bin plasma-wayland-protocols >/dev/null 2>&1
fi

cd /work || fail "no /work tmpfs"

echo "### build fake_input client ###"
wayland-scanner client-header /usr/share/plasma-wayland-protocols/fake-input.xml fake-input-client-protocol.h
wayland-scanner private-code  /usr/share/plasma-wayland-protocols/fake-input.xml fake-input-protocol.c
gcc -O2 -I/work -o fakeinput /opt/hw/fakeinput.c fake-input-protocol.c -lwayland-client || fail "fakeinput build"

echo "### build + install the effect ###"
cmake -S /opt/effect -B /work/build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release >/work/cmake.log 2>&1 || { tail -20 /work/cmake.log; fail "cmake config"; }
cmake --build /work/build -j"$(nproc)" >/work/make.log 2>&1 || { tail -30 /work/make.log; fail "compile"; }
QTP=$(qtpaths6 --plugin-dir 2>/dev/null || echo /usr/lib/x86_64-linux-gnu/qt6/plugins)
mkdir -p "$QTP/kwin/effects/plugins"
cp /work/build/fancyzones.so "$QTP/kwin/effects/plugins/" || fail "install plugin"
echo "installed to $QTP/kwin/effects/plugins/"

echo "### headless kwin_wayland + load effect + inject input ###"
export XDG_RUNTIME_DIR=/tmp/xdgrt; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
eval "$(dbus-launch --sh-syntax)"; export DBUS_SESSION_BUS_ADDRESS
# Software compositing + expose the privileged fake_input protocol.
export KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 LIBGL_ALWAYS_SOFTWARE=1 KWIN_COMPOSE=O WAYLAND_DISPLAY=wayland-0
kwin_wayland --virtual --width 1920 --height 1080 --no-lockscreen >/logs/kww.log 2>&1 &
for _ in $(seq 1 80); do gdbus introspect --session --dest org.kde.KWin --object-path /KWin >/dev/null 2>&1 && break; sleep 0.3; done
gdbus introspect --session --dest org.kde.KWin --object-path /KWin >/dev/null 2>&1 || { tail -20 /logs/kww.log; fail "kwin_wayland did not start"; }
sleep 1

loaded=$(gdbus call --session --dest org.kde.KWin --object-path /Effects --method org.kde.kwin.Effects.loadEffect fancyzones 2>&1)
echo "loadEffect fancyzones -> $loaded"
[ "$loaded" = "(true,)" ] || fail "effect did not load (see /logs/kww.log)"
sleep 1

# Hold Shift, move the pointer, release Shift, move again. (evdev: 42=LEFTSHIFT)
printf 'k 42 1\ns 200\nm 500 500\ns 200\nm 900 700\ns 200\nk 42 0\ns 200\nm 600 600\ns 200\nq\n' | ./fakeinput >/dev/null 2>&1
sleep 1

echo "----- [fzeffect] log -----"
grep "\[fzeffect\]" /logs/kww.log | tail -8 || echo "(none)"
echo "--------------------------"
grep -q "shift= true" /logs/kww.log || fail "effect never observed the Shift modifier"

echo "EFFECT TEST PASSED — C++ effect loaded headless and read the Shift modifier live"
