#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/vm.env"

IMAGE="ghcr.io/astral-sh/uv:0.12.3-debian"

echo "==> Starting uv image"
exec ssh -tt "${SSH_OPTS[@]}" "${SSH_TARGET}" "podman run --rm -it ${IMAGE} bash"
