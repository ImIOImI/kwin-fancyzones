#!/usr/bin/env bash
# Build the comprehensive testing image (all tools baked in) from Dockerfile.effect.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${FZ_EFFECT_IMAGE:-kwin-fancyzones-test:dev}"
UBUNTU_VERSION="${UBUNTU_VERSION:-25.04}"

echo "Building $IMAGE from ubuntu:$UBUNTU_VERSION (this pulls KWin + Qt6/KF6 dev — sizeable)..."
docker build \
  --build-arg "UBUNTU_VERSION=$UBUNTU_VERSION" \
  -t "$IMAGE" \
  -f "$REPO/docker/Dockerfile.effect" \
  "$REPO"
echo "Built $IMAGE"
