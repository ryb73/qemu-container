#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/vm.env"

echo "==> Building hello image"
ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" \
  'podman build -t hello https://github.com/containers/PodmanHello.git'

echo "==> Running hello image"
ssh -t "${SSH_OPTS[@]}" "${SSH_TARGET}" \
  'podman run --rm -it \
    --network=none \
    --cap-drop=all \
    --security-opt=no-new-privileges \
    --pids-limit=100 \
    --memory=512m \
    hello'
