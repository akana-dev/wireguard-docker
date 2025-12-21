#!/bin/bash
CLIENT_NAME="${1:-}"
if [[ -z "$CLIENT_NAME" ]]; then
  echo "Usage: $0 <client_name>" >&2
  exit 1
fi

WG_CONF="/config/wg_confs/wg0.conf"

if ! grep -q "^### Client ${CLIENT_NAME}\$" "$WG_CONF"; then
  echo "Client '$CLIENT_NAME' not found." >&2
  exit 1
fi

# Удаляем блок клиента
sed -i "/^### Client ${CLIENT_NAME}\$/,/^$/d" "$WG_CONF"

# Удаляем файл клиента
rm -f "/config/clients/${CLIENT_NAME}.conf"

# Обновляем интерфейс
wg syncconf wg0 <(wg-quick strip wg0)
wg-quick down wg0 && wg-quick up wg0

echo "🗑️ Client '$CLIENT_NAME' revoked."
