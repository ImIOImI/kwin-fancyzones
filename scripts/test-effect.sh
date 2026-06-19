#!/usr/bin/env bash
# Build + headless-test the C++ KWin effect end-to-end.
#
# Unlike scripts/test.sh (the unprivileged X11/Xvfb harness for the script-level
# zone logic), the effect must run inside a real compositor, so this needs:
#   - a PRIVILEGED container (kwin_wayland file caps; fake_input/uinput access)
#   - software compositing (kwin_wayland --virtual + llvmpipe EGL)
#   - fake_input injection (org_kde_kwin_fake_input)
#
# First run installs build/wayland deps into the container at runtime (slow).
# TODO: bake those into a dedicated docker/Dockerfile.effect image to speed this up.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${FZ_IMAGE:-kwin-fancyzones:dev}"

docker image inspect "$IMAGE" >/dev/null 2>&1 || "$REPO/scripts/build-image.sh"
mkdir -p "$REPO/out"

exec docker run --rm --privileged \
  -v "$REPO/effect:/opt/effect:ro" \
  -v "$REPO/scripts/harness-wayland:/opt/hw:ro" \
  -v "$REPO/out:/logs" \
  --tmpfs /work:exec \
  "$IMAGE" bash /opt/hw/run-effect-test.sh
