#!/usr/bin/env bash
# Build the headless KWin test image.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${FZ_IMAGE:-kwin-fancyzones:dev}"
UBUNTU_VERSION="${UBUNTU_VERSION:-25.04}"

echo "Building $IMAGE from ubuntu:$UBUNTU_VERSION ..."
docker build \
  --build-arg "UBUNTU_VERSION=$UBUNTU_VERSION" \
  -t "$IMAGE" \
  -f "$REPO/docker/Dockerfile" \
  "$REPO"
echo "Built $IMAGE"
