#!/bin/bash
set -euo pipefail

if [[ ! -f qemu.pid ]]; then
  echo "No qemu.pid found. Is the VM running?"
  exit 1
fi

PID=$(cat qemu.pid)

# Guard against PID reuse: daemonized processes are reparented to init, which
# reaps them promptly, freeing the PID for recycling before we finish polling.
qemu_running() {
  kill -s 0 "$1" 2>/dev/null && ps -p "$1" -o comm= 2>/dev/null | grep -q qemu
}

if ! qemu_running "${PID}"; then
  echo "Process ${PID} is not running. Cleaning up stale files."
  rm -f qemu.pid monitor.sock
  exit 1
fi

if [[ -S monitor.sock ]]; then
  echo "Sending ACPI shutdown..."
  printf "system_powerdown\n" | nc -w 2 -U monitor.sock >/dev/null 2>&1 || {
    echo "Monitor unresponsive, killing process..."
    kill "${PID}"
  }
else
  echo "No monitor socket found, killing process..."
  kill "${PID}"
fi

echo "Waiting for VM to shut down..."
trap 'echo "Interrupted. Cleaning up..."; rm -f qemu.pid monitor.sock; echo "Done."; exit 130' INT
for _ in $(seq 1 60); do
  qemu_running "${PID}" || break
  sleep 0.5 || true
done
trap - INT

if qemu_running "${PID}"; then
  echo "VM did not shut down in time, killing..."
  kill "${PID}"
fi

rm -f qemu.pid monitor.sock
echo "Done."
