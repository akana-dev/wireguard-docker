#!/bin/bash
grep -oP '^### Client \K.*' /config/wg_confs/wg0.conf || echo "No clients found."
