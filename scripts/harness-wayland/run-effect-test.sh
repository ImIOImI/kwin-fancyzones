#!/usr/bin/env bash
# In-container: build the C++ effect + fake_input client, then verify the effect's
# move-hooked, Shift-gated activation by actually moving a real (Xwayland) window:
#   - drag WITHOUT Shift -> effect must NOT activate the overlay
#   - drag WITH Shift     -> effect activates, then deactivates when the move ends
#
# Each scenario runs in a FRESH kwin_wayland session (window at a known position),
# so there's no cross-scenario input/window state to confuse the result.
#
# Must run PRIVILEGED; KWIN_WAYLAND_NO_PERMISSION_CHECKS exposes fake_input.
# Mounts: /opt/effect, /opt/hw (this dir), /logs.
set -uo pipefail
fail() { echo "EFFECT TEST FAILED: $*" >&2; exit 1; }

if ! command -v kwin_wayland >/dev/null || ! command -v cmake >/dev/null || ! command -v Xwayland >/dev/null; then
  echo "### installing build + wayland deps (first run on a non-baked image is slow) ###"
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq --no-install-recommends \
    cmake extra-cmake-modules g++ make \
    kwin-dev qt6-base-dev qt6-base-dev-tools qt6-declarative-dev \
    libkf6coreaddons-dev libxkbcommon-dev \
    kwin-wayland xwayland xterm xfonts-base x11-utils libegl1 libegl-mesa0 libgles2 \
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
mkdir -p "$QTP/kwin/effects/plugins"; cp /work/build/fancyzones.so "$QTP/kwin/effects/plugins/" || fail "install plugin"

export XDG_RUNTIME_DIR=/tmp/xdgrt; mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
eval "$(dbus-launch --sh-syntax)"; export DBUS_SESSION_BUS_ADDRESS
export KWIN_WAYLAND_NO_PERMISSION_CHECKS=1 LIBGL_ALWAYS_SOFTWARE=1 WAYLAND_DISPLAY=wayland-0
export KWIN_COMPOSE="${KWIN_COMPOSE:-O}"   # O=OpenGL (default), Q=QPainter (exercises the software path)
export FZ_CAPTURE=/logs/overlay.png   # the effect saves the overlay's render here when active
rm -f /logs/overlay.png

# Run one drag scenario in a fresh kwin_wayland session. $1=logfile, $2="shift"|"".
scenario() {
  local logf="$1" shift="${2:-}"
  rm -f "$XDG_RUNTIME_DIR"/wayland-0* 2>/dev/null
  kwin_wayland --virtual --width 1920 --height 1080 --xwayland --no-lockscreen /opt/hw/session.sh >"$logf" 2>&1 &
  local kpid=$!
  local _; for _ in $(seq 1 80); do gdbus introspect --session --dest org.kde.KWin --object-path /KWin >/dev/null 2>&1 && break; sleep 0.3; done
  gdbus introspect --session --dest org.kde.KWin --object-path /KWin >/dev/null 2>&1 || { kill $kpid 2>/dev/null; fail "kwin_wayland did not start"; }
  local loaded; loaded=$(gdbus call --session --dest org.kde.KWin --object-path /Effects --method org.kde.kwin.Effects.loadEffect fancyzones 2>&1)
  [ "$loaded" = "(true,)" ] || { kill $kpid 2>/dev/null; fail "effect did not load ($loaded)"; }
  gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.loadDeclarativeScript /opt/hw/setup/contents/ui/main.qml fzsetup >/dev/null 2>&1
  gdbus call --session --dest org.kde.KWin --object-path /Scripting --method org.kde.kwin.Scripting.start >/dev/null 2>&1
  for _ in $(seq 1 60); do grep -q "\[setup\] positioned" "$logf" && break; sleep 0.3; done
  grep -q "\[setup\] positioned" "$logf" || { kill $kpid 2>/dev/null; fail "test window never appeared/positioned"; }

  # evdev: Meta=125 (move modifier), Shift=42, LeftButton=272. Window is 100,100 1700x880; 950,540 is inside.
  # Headless windows have no titlebar to drag, so start the move with Meta+Left (the
  # move binding is exactly Meta, so Shift can't be held at start). For the Shift
  # scenario, press Shift MID-drag — the effect re-evaluates the gate on the next
  # mouseChanged, which is the live "Shift while dragging" behavior.
  # Drag toward the LEFT zone (drop cursor at 300,540 — inside "left" only). For the
  # Shift scenario, press Shift mid-drag and keep it held THROUGH the finish so the
  # snap fires; expect highlight "left" and a snap to the left zone (0,0 640x1080).
  { echo "k 125 1"; echo "s 150"
    echo "m 950 540"; echo "s 150"
    echo "b 272 1"; echo "s 200"        # Meta+Left => start interactive move
    echo "m 700 540"; echo "s 150"      # dragging (no Shift yet)
    if [ "$shift" = "shift" ]; then
      echo "k 42 1"; echo "s 100"       # press Shift mid-drag => gate activates (overlay shown)
      echo "m 500 540"; echo "s 200"
      echo "m 300 540"; echo "s 200"    # cursor now inside the LEFT zone => highlight "left"
      echo "s 500"                       # hold so the overlay renders + highlight settles
      echo "b 272 0"; echo "s 200"      # finish WITH Shift held => snap to left
      echo "k 42 0"; echo "s 100"
    else
      echo "m 500 540"; echo "s 150"; echo "m 300 540"; echo "s 150"
      echo "b 272 0"; echo "s 150"      # finish, no snap
    fi
    echo "k 125 0"; echo "s 200"; echo "q"; } | ./fakeinput >/dev/null 2>&1
  sleep 0.8
  kill $kpid 2>/dev/null; pkill -f kwin_wayland 2>/dev/null; pkill -x xterm 2>/dev/null; sleep 1
}

echo "### scenario A: drag WITHOUT Shift ###"
scenario /logs/scen-noshift.log ""
echo "### scenario B: drag WITH Shift ###"
scenario /logs/scen-shift.log shift

echo "----- no-shift [fzeffect]/[overlay] -----"; grep -E "\[fzeffect\]|\[overlay\]" /logs/scen-noshift.log || true
echo "----- shift    [fzeffect]/[overlay] -----"; grep -E "\[fzeffect\]|\[overlay\]" /logs/scen-shift.log || true
echo "-----------------------------------------"

# no-shift: a move happened but the overlay must NOT have shown, and NO snap.
grep -q "move start.*shift= false" /logs/scen-noshift.log || fail "no-shift: move not detected"
grep -q "overlay SHOWN"            /logs/scen-noshift.log && fail "no-shift: overlay activated without Shift"
grep -q "\[fzeffect\] snapped"     /logs/scen-noshift.log && fail "no-shift: window snapped without Shift"
# shift: overlay rendered, highlighted the LEFT zone, the drag survived, snapped the
# window to the left zone (0,0 640x1080), and the overlay hid on finish.
grep -q "overlay SHOWN"            /logs/scen-shift.log   || fail "shift: overlay did not activate"
grep -q "\[fzeffect\] highlight left" /logs/scen-shift.log || fail "shift: did not highlight the left zone under the cursor"
grep -q "\[fzeffect\] move finish" /logs/scen-shift.log   || fail "shift: the drag was CANCELLED by the overlay (no move finish)"
grep -q "\[fzeffect\] snapped to left" /logs/scen-shift.log || fail "shift: did not snap to the left zone"
grep -q "640x1080"                 /logs/scen-shift.log   || fail "shift: snap geometry is not the left zone (expected 640x1080)"
grep -q "overlay hidden"           /logs/scen-shift.log   || fail "shift: overlay did not deactivate on finish"
# the passive OffscreenQuickScene overlay actually rendered (captured to a PNG).
grep -q "\[fzeffect\] captured overlay" /logs/scen-shift.log || fail "shift: overlay did not render (no capture)"
[ -s /logs/overlay.png ] || fail "shift: overlay.png not written"
echo "overlay rendered -> /logs/overlay.png ($(stat -c%s /logs/overlay.png) bytes)"

echo "EFFECT TEST PASSED — Shift-gated overlay highlights the cursor's zone and snaps the window to it on drop"
