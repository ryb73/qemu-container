#!/bin/bash
set -euo pipefail

SSH_TARGET="debian@localhost"
SSH_PORT=2222
IMAGE="ghcr.io/openhands/agent-canvas:1.10.0"
# Image runs as openhands (uid/gid 10001); rootless podman remaps our host
# uid to root inside the container's user namespace, so bind mounts must be
# rechowned via `podman unshare` or the app can't write to them.
CONTAINER_UID=10001
CONTAINER_GID=10001
READY_TIMEOUT=60

echo "==> Preparing persistent directories"
ssh -p "${SSH_PORT}" "${SSH_TARGET}" \
  "mkdir -p ~/.openhands ~/projects
   podman unshare chown -R ${CONTAINER_UID}:${CONTAINER_GID} ~/.openhands ~/projects"

echo "==> Pulling Agent Canvas image"
ssh -p "${SSH_PORT}" "${SSH_TARGET}" "podman pull ${IMAGE}"

echo "==> Starting Agent Canvas"
# Not using `podman run --rm`: on a crash it would delete the container
# before the diagnostics below can `podman logs` it.
ssh -p "${SSH_PORT}" "${SSH_TARGET}" \
  "podman rm -f agent-canvas >/dev/null 2>&1 || true
   podman run -d --name agent-canvas \
     -p 8000:8000 \
     -v ~/.openhands:/home/openhands/.openhands \
     -v ~/projects:/projects \
     ${IMAGE}"

echo "==> Waiting for Agent Canvas to become ready"
SECONDS=0
until ssh -p "${SSH_PORT}" "${SSH_TARGET}" 'curl -sf -o /dev/null http://localhost:8000/health' 2>/dev/null; do
  if ! ssh -p "${SSH_PORT}" "${SSH_TARGET}" 'podman inspect -f "{{.State.Running}}" agent-canvas' 2>/dev/null | grep -q true; then
    echo "Error: agent-canvas container exited unexpectedly. Recent logs:" >&2
    ssh -p "${SSH_PORT}" "${SSH_TARGET}" 'podman logs --tail 50 agent-canvas' >&2
    exit 1
  fi
  if (( SECONDS >= READY_TIMEOUT )); then
    echo "Error: timed out after ${READY_TIMEOUT}s waiting for Agent Canvas to become ready. Recent logs:" >&2
    ssh -p "${SSH_PORT}" "${SSH_TARGET}" 'podman logs --tail 50 agent-canvas' >&2
    exit 1
  fi
  sleep 1
done

echo ""
echo "Agent Canvas running. Open http://localhost:8000 in your browser to finish first-time setup (agent, LLM provider/API key, etc)."
