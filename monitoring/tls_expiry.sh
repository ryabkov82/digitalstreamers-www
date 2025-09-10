#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-localhost}"
PORT="${2:-443}"
WARN_DAYS="${3:-30}"

expiry_date=$(echo | openssl s_client -servername "$HOST" -connect "$HOST:$PORT" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)

if [[ -z "$expiry_date" ]]; then
  echo "Failed to fetch certificate for $HOST:$PORT" >&2
  exit 1
fi

expiry_epoch=$(date -d "$expiry_date" +%s)
now_epoch=$(date +%s)

days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

if (( days_left <= WARN_DAYS )); then
  echo "Certificate for $HOST expires in $days_left days" >&2
  exit 1
else
  echo "Certificate for $HOST valid for $days_left days"
fi
