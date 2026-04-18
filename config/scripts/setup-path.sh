#!/bin/bash
chown -R 1000:1000 /config 2>/dev/null || true

ln -sf /config/scripts/add-client.sh /usr/local/bin/add
ln -sf /config/scripts/list-clients.sh /usr/local/bin/list
ln -sf /config/scripts/revoke-client.sh /usr/local/bin/revoke

exec /init "$@"