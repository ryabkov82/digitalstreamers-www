#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost}"
INTERVAL="${INTERVAL:-60}"

check() {
  for path in /api/health /api/status; do
    if ! curl -fsS "${BASE_URL}${path}" >/dev/null; then
      echo "\"${BASE_URL}${path}\" is unreachable" >&2
      return 1
    fi
  done
}

while true; do
  if ! check; then
    exit 1
  fi
  sleep "$INTERVAL"
done
