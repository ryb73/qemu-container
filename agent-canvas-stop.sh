#!/bin/bash
set -euo pipefail

SSH_TARGET="debian@localhost"
SSH_PORT=2222

if ! ssh -p "${SSH_PORT}" "${SSH_TARGET}" 'podman container exists agent-canvas' 2>/dev/null; then
  echo "No agent-canvas container found. Nothing to do."
  exit 0
fi

echo "==> Stopping Agent Canvas"
ssh -p "${SSH_PORT}" "${SSH_TARGET}" 'podman stop agent-canvas >/dev/null'
ssh -p "${SSH_PORT}" "${SSH_TARGET}" 'podman rm agent-canvas >/dev/null'

echo "Agent Canvas stopped."
