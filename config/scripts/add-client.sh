#!/bin/bash
set -e

CLIENT_NAME="${1:-}"
if [[ -z "$CLIENT_NAME" ]] || [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]] || [[ ${#CLIENT_NAME} -gt 15 ]]; then
  echo "Usage: $0 <client_name>" >&2
  echo "Client name must be alphanumeric (underscores/dashes allowed), max 15 chars."
  exit 1
fi

WG_CONF="/config/wg_confs/wg0.conf"
CLIENTS_DIR="/config/clients"
TEMPLATE="/config/templates/peer.conf"

[[ -f "$WG_CONF" ]] || { echo "Error: $WG_CONF not found." >&2; exit 1; }
[[ -f "$TEMPLATE" ]] || { echo "Error: $TEMPLATE not found." >&2; exit 1; }

SERVER_PRIV_KEY=$(grep -oP 'PrivateKey = \K.*' "$WG_CONF")
SERVER_PUB_KEY=$(wg pubkey <<< "$SERVER_PRIV_KEY")
SERVER_PORT=$(grep -oP 'ListenPort = \K.*' "$WG_CONF")
SERVER_WG_IPV4=$(grep -oP 'Address = \K[^,]*' "$WG_CONF")
SERVER_WG_IPV6=$(grep -oP 'Address = [^,]*,\K[^/]*' "$WG_CONF" || echo "")

grep -q "### Client ${CLIENT_NAME}\$" "$WG_CONF" && { echo "Client '$CLIENT_NAME' already exists." >&2; exit 1; }

BASE_IPV4=$(echo "$SERVER_WG_IPV4" | cut -d'.' -f1-3)
for i in {2..254}; do
  IP="${BASE_IPV4}.${i}"
  if ! grep -q "$IP/32" "$WG_CONF"; then
    CLIENT_WG_IPV4="$IP"
    break
  fi
done
[[ -z "$CLIENT_WG_IPV4" ]] && { echo "No free IPv4 addresses left." >&2; exit 1; }

if [[ -n "$SERVER_WG_IPV6" ]]; then
  BASE_IPV6=$(echo "$SERVER_WG_IPV6" | cut -d':' -f1-4)
  for i in {2..254}; do
    IP6="${BASE_IPV6}::${i}"
    if ! grep -q "$IP6/128" "$WG_CONF"; then
      CLIENT_WG_IPV6="$IP6"
      break
    fi
  done
fi

CLIENT_PRIV_KEY=$(wg genkey)
CLIENT_PUB_KEY=$(wg pubkey <<< "$CLIENT_PRIV_KEY")
PRESHARED_KEY=$(wg genpsk)

PEER_DIR="/config/${CLIENT_NAME}"
mkdir -p "$PEER_DIR" "$CLIENTS_DIR"

echo "$CLIENT_PRIV_KEY" > "$PEER_DIR/privatekey-${CLIENT_NAME}"
echo "$PRESHARED_KEY" > "$PEER_DIR/presharedkey-${CLIENT_NAME}"
echo "$SERVER_PUB_KEY" > "/config/server/publickey-server"

export CLIENT_IP="${CLIENT_WG_IPV4}/32${CLIENT_WG_IPV6:+,$CLIENT_WG_IPV6/128}"
export PEER_ID="$CLIENT_NAME"
export PEERDNS="$PEERDNS"
export SERVERURL="$SERVERURL"
export SERVERPORT="$SERVERPORT"
export ALLOWEDIPS="0.0.0.0/0,::/0"
export CLIENT_PRIVATE_KEY="$CLIENT_PRIV_KEY"
export SERVER_PUBLIC_KEY="$SERVER_PUB_KEY"
export PRESHARED_KEY="$PRESHARED_KEY"

CLIENT_CONFIG_CONTENT=$(sed \
  -e "s|\${CLIENT_IP}|$CLIENT_IP|g" \
  -e "s|\${PEER_ID}|$PEER_ID|g" \
  -e "s|\${PEERDNS}|$PEERDNS|g" \
  -e "s|\${SERVERURL}|$SERVERURL|g" \
  -e "s|\${SERVERPORT}|$SERVERPORT|g" \
  -e "s|\${ALLOWEDIPS}|$ALLOWEDIPS|g" \
  -e "s|\${CLIENT_PRIVATE_KEY}|$CLIENT_PRIVATE_KEY|g" \
  -e "s|\${SERVER_PUBLIC_KEY}|$SERVER_PUBLIC_KEY|g" \
  -e "s|\${PRESHARED_KEY}|$PRESHARED_KEY|g" \
  "$TEMPLATE")

echo "$CLIENT_CONFIG_CONTENT"

echo "$CLIENT_CONFIG_CONTENT" > "$CLIENTS_DIR/${CLIENT_NAME}.conf"

cat >> "$WG_CONF" <<EOF

### Client $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUB_KEY
PresharedKey = $PRESHARED_KEY
AllowedIPs = $CLIENT_WG_IPV4/32${CLIENT_WG_IPV6:+,$CLIENT_WG_IPV6/128}
EOF

wg-quick down wg0 && wg-quick up wg0

qrencode -t ansiutf8 <<< "$CLIENT_CONFIG_CONTENT" 2>/dev/null || true

echo "✅ Client '$CLIENT_NAME' created!"
echo "📄 Config saved to: $CLIENTS_DIR/${CLIENT_NAME}.conf"