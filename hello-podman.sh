#!/bin/bash
set -euo pipefail

SSH_TARGET="debian@localhost"
SSH_PORT=2222

echo "==> Building hello image"
ssh -p "${SSH_PORT}" "${SSH_TARGET}" \
  'podman build -t hello https://github.com/containers/PodmanHello.git'

echo "==> Running hello image"
ssh -t -p "${SSH_PORT}" "${SSH_TARGET}" \
  'podman run --rm -it \
    --network=none \
    --cap-drop=all \
    --security-opt=no-new-privileges \
    --pids-limit=100 \
    --memory=512m \
    hello'
