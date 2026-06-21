#!/usr/bin/env bash
# Build, install, and enable the kwin-fancyzones effect on a real KDE Plasma 6 desktop.
#
# Requires Plasma 6 / KWin 6 (Kubuntu 24.10+ — 25.04 recommended; NOT 24.04 LTS,
# which is still Plasma 5). Run it on the machine where you use KDE.
#
#   git clone https://github.com/ImIOImI/kwin-fancyzones && cd kwin-fancyzones
#   ./scripts/install.sh
#
# Then drag a window with Shift held to snap it to a zone.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "==> KWin version"
kwin_wayland --version 2>/dev/null || kwin_x11 --version 2>/dev/null || echo "  (kwin not found yet)"

echo "==> Installing build dependencies"
$SUDO apt-get update
$SUDO apt-get install -y --no-install-recommends \
  cmake extra-cmake-modules g++ \
  kwin-dev qt6-base-dev qt6-base-dev-tools qt6-declarative-dev \
  libkf6coreaddons-dev libxkbcommon-dev

echo "==> Building the effect"
cmake -S "$REPO/effect" -B "$REPO/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$REPO/build" -j"$(nproc)"

# Install to the dir KWin actually scans for plugin effects (the Qt6 plugin dir).
QTP="$(qtpaths6 --plugin-dir 2>/dev/null || echo /usr/lib/x86_64-linux-gnu/qt6/plugins)"
DEST="$QTP/kwin/effects/plugins"
echo "==> Installing plugin to $DEST"
$SUDO mkdir -p "$DEST"
$SUDO cp "$REPO/build/fancyzones.so" "$DEST/"

echo "==> Enabling the effect"
kwriteconfig6 --file kwinrc --group Plugins --key fancyzonesEnabled true 2>/dev/null \
  || echo "  (kwriteconfig6 not found; enable 'KWin FancyZones' in System Settings > Window Management > Desktop Effects)"

echo "==> Activating now (if a session is running)"
if qdbus6 org.kde.KWin /Effects loadEffect fancyzones 2>/dev/null \
   || qdbus org.kde.KWin /Effects loadEffect fancyzones 2>/dev/null; then
  echo "  effect loaded into the running session."
else
  echo "  couldn't hot-load — log out/in (or run: kwin_wayland --replace) to activate."
fi

cat <<'MSG'

Done. Try it: drag a window and hold Shift -> the zone overlay appears; release to
snap. (Default zones: 3-column grid + a lower-center "focus" zone. Edit them for now
in effect/contents/ui/overlay.qml and the C++ zone list, then re-run this script.)
MSG
