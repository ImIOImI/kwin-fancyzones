#!/usr/bin/env bash
# Build + headless-test the C++ KWin effect end-to-end.
#
# Unlike scripts/test.sh (the unprivileged X11/Xvfb harness for the script-level
# zone logic), the effect must run inside a real compositor, so this needs:
#   - a PRIVILEGED container (kwin_wayland file caps)
#   - software compositing (kwin_wayland --virtual + llvmpipe EGL)
#   - fake_input injection (org_kde_kwin_fake_input)
#
# Image: the comprehensive testing image (all tools baked in). By default builds it
# locally from docker/Dockerfile.effect; set FZ_IMAGE to use a prebuilt one, e.g.
# the GHCR image published by CI:
#   FZ_IMAGE=ghcr.io/imioimi/kwin-fancyzones-test:latest ./scripts/test-effect.sh
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${FZ_IMAGE:-kwin-fancyzones-test:dev}"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  if [ -n "${FZ_IMAGE:-}" ]; then
    echo "Pulling $IMAGE ..."; docker pull "$IMAGE"
  else
    "$REPO/scripts/build-effect-image.sh"
  fi
fi

mkdir -p "$REPO/out"

exec docker run --rm --privileged \
  -v "$REPO/effect:/opt/effect:ro" \
  -v "$REPO/scripts/harness-wayland:/opt/hw:ro" \
  -v "$REPO/out:/logs" \
  --tmpfs /work:exec \
  "$IMAGE" bash /opt/hw/run-effect-test.sh
