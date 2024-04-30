#!/usr/bin/env bash
set -xefuo pipefail
if [[ $(docker buildx version >/dev/null 2>&1) ]]; then
  echo >&2 "docker buildx is not installed"
  exit 1
fi
WD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pushd "${WD}" >/dev/null 2>&1
# ────────────────────────────────────────────────────────────
BUILDKIT_PROGRESS="${BUILDKIT_PROGRESS:-"plain"}"
export BUILDKIT_PROGRESS

LOCAL="${LOCAL:-"true"}"
export LOCAL

IMAGE_NAME="${IMAGE_NAME:-$(basename "$(git rev-parse --show-prefix)")}"
export IMAGE_NAME
# ────────────────────────────────────────────────────────────
CHAOTIC_AUR_KEY="${CHAOTIC_AUR_KEY:-"3056513887B78AEB"}"
# ────────────────────────────────────────────────────────────
BUILDER="$(basename -s.git "$(git remote get-url origin)")"
! docker buildx inspect "${BUILDER}" >/dev/null 2>&1 && docker buildx create --bootstrap --name "${BUILDER}" --driver "docker-container"
docker buildx use "${BUILDER}"
# ────────────────────────────────────────────────────────────
: "${CHAOTIC_AUR_KEY:?Variable not set or empty}"
docker buildx bake \
  --set "default.args.CHAOTIC_AUR_KEY=${CHAOTIC_AUR_KEY}"
# ────────────────────────────────────────────────────────────
popd >/dev/null 2>&1
