#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/vm.env"

if ! ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" 'podman container exists agent-canvas' 2>/dev/null; then
  echo "No agent-canvas container found. Nothing to do."
  exit 0
fi

echo "==> Stopping Agent Canvas"
ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" 'podman stop agent-canvas >/dev/null'
ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" 'podman rm agent-canvas >/dev/null'

echo "Agent Canvas stopped."
