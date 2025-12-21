#!/bin/bash
ln -sf /config/scripts/add-client.sh /usr/local/bin/add
ln -sf /config/scripts/list-clients.sh /usr/local/bin/list
ln -sf /config/scripts/revoke-client.sh /usr/local/bin/revoke


# Затем запускаем оригинальный entrypoint linuxserver/wireguard
exec /init "$@"
