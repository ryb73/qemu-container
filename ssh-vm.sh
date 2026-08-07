#!/bin/bash
set -euo pipefail

SCRIPT_REALPATH=$(realpath "$0")
source "$(dirname "${SCRIPT_REALPATH}")/vm.env"

exec ssh "${SSH_OPTS[@]}" "${SSH_TARGET}" "$@"
