#!/usr/bin/env bash
set -e

echo "Starting OpenCloud..."

mkdir -p "$OC_DATA_DIR" "$OC_CONFIG_DIR"
chown -R 1000:1000 "$OC_DATA_DIR" "$OC_CONFIG_DIR"

opencloud server \
  --data-dir "$OC_DATA_DIR" \
  --config-dir "$OC_CONFIG_DIR"
