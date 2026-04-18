#!/bin/bash
set -euo pipefail

CLIENT_NAME="${1:-}"
if [[ -z "$CLIENT_NAME" ]]; then
  echo "Usage: $0 <client_name>" >&2
  exit 1
fi

WG_CONF="/config/wg_confs/wg0.conf"

if ! grep -q "^### Client ${CLIENT_NAME}\$" "$WG_CONF"; then
  echo "⚠️ Client '$CLIENT_NAME' not found." >&2
  exit 1
fi

CLIENT_PUB_KEY=$(awk "/^### Client ${CLIENT_NAME}\$/,/^\$/{if(/PublicKey = /) print \$3}" "$WG_CONF")
if [[ -n "$CLIENT_PUB_KEY" ]]; then
  wg set wg0 peer "$CLIENT_PUB_KEY" remove 2>/dev/null || true
fi

awk -v name="### Client $CLIENT_NAME" '
  $0 ~ name {skip=1; next}
  skip && /^$/ {skip=0; next}
  !skip {print}
' "$WG_CONF" > "${WG_CONF}.tmp" && mv "${WG_CONF}.tmp" "$WG_CONF"

rm -rf "/config/clients/${CLIENT_NAME}"
echo "🗑️ Client '$CLIENT_NAME' revoked."