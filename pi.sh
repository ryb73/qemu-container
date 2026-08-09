#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/vm.env"

echo "==> Building pi image"
ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" \
  'podman build -t pi -f -' < "$(dirname "${BASH_SOURCE[0]}")/pi/Containerfile"

echo "==> Starting pi image"
exec ssh -tt "${SSH_OPTS[@]}" "${SSH_TARGET}" "podman run --rm -it pi bash"
