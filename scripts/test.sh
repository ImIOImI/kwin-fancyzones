#!/usr/bin/env bash
# Build the image if needed, then run a harness command in the container.
#   ./scripts/test.sh            # run the smoke test (default)
#   ./scripts/test.sh smoke      # same
#   ./scripts/test.sh session    # bring the session up and hold (use with -it; see README)
#   ./scripts/test.sh shell      # drop into a shell in the container
# The KWin script in ./src is bind-mounted, so edits take effect without rebuilding.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${FZ_IMAGE:-kwin-fancyzones:dev}"
CMD="${1:-test}"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  "$REPO/scripts/build-image.sh"
fi

mkdir -p "$REPO/out"

TTY_FLAGS=()
if [ "$CMD" = "session" ] || [ "$CMD" = "shell" ]; then
  [ -t 0 ] && TTY_FLAGS=(-it)
fi

exec docker run --rm "${TTY_FLAGS[@]}" \
  -v "$REPO/src:/opt/fz/src:ro" \
  -v "$REPO/out:/opt/fz/logs" \
  "$IMAGE" "$CMD"
