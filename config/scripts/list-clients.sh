#!/bin/bash

set -euo pipefail

WG_INTERFACE="wg0"
WG_CONF="/config/wg_confs/wg0.conf"

if [[ ! -f "$WG_CONF" ]]; then
  echo "Error: $WG_CONF not found." >&2
  exit 1
fi

declare -A CLIENT_NAMES
while IFS= read -r line; do
  if [[ $line =~ ^###\ Client\ ([a-zA-Z0-9_-]+)$ ]]; then
    CLIENT_NAME="${BASH_REMATCH[1]}"
  elif [[ $line =~ ^PublicKey\ =\ ([^$]+)$ ]]; then
    PUBKEY="${BASH_REMATCH[1]}"
    CLIENT_NAMES["$PUBKEY"]="$CLIENT_NAME"
  fi
done < "$WG_CONF"

WG_SHOW_OUTPUT=$(wg show "$WG_INTERFACE" 2>/dev/null || true)

if [[ -z "$WG_SHOW_OUTPUT" ]]; then
  echo "WireGuard interface '$WG_INTERFACE' is not active."
  exit 1
fi

echo "Name            | Endpoint             | Latest Handshake        | Transfer (Rx/Tx)     "
echo "----------------|----------------------|-------------------------|----------------------"

while IFS= read -r line; do
  if [[ $line =~ ^peer:\ ([^$]+)$ ]]; then
    PUBKEY="${BASH_REMATCH[1]}"
    CLIENT_NAME="${CLIENT_NAMES[$PUBKEY]:-unknown}"
    ENDPOINT=""
    HANDSHAKE=""
    RX=""
    TX=""
  elif [[ $line =~ allowed\ ips:\ .* ]]; then
    continue
  elif [[ $line =~ endpoint:\ (.*) ]]; then
    ENDPOINT="${BASH_REMATCH[1]}"
  elif [[ $line =~ latest\ handshake:\ (.*) ]]; then
    HANDSHAKE="${BASH_REMATCH[1]}"
  elif [[ $line =~ transfer:\ (.*)\ received,\ (.*)\ sent ]]; then
    RX="${BASH_REMATCH[1]}"
    TX="${BASH_REMATCH[2]}"
    printf "%-15s | %-20s | %-23s | %-10s / %-10s\n" \
      "$CLIENT_NAME" "$ENDPOINT" "$HANDSHAKE" "$RX" "$TX"
  fi
done <<< "$WG_SHOW_OUTPUT"