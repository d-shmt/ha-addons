#!/bin/bash

# Pfad zur HA Config-Datei (wird von HA unter /data/options.json abgelegt)
CONFIG_PATH=/data/options.json

# Werte mit jq extrahieren (da wir im offiziellen Image kein volles bashio haben)
DOMAIN=$(jq --raw-output '.domain' $CONFIG_PATH)
ADMIN_PASSWORD=$(jq --raw-output '.admin_password' $CONFIG_PATH)

echo "[INFO] Starte OpenCloud für Domain: ${DOMAIN}"

# Verzeichnisse auf dem NFS-Share (HA /share ist gemountet)
export OCIS_BASE_DATA_PATH="/share/opencloud/data"
export OCIS_CONFIG_DIR="/share/opencloud/config"
mkdir -p $OCIS_BASE_DATA_PATH $OCIS_CONFIG_DIR

# --- OpenCloud Konfiguration ---
export OCIS_URL="https://${DOMAIN}"
export OCIS_LOG_LEVEL=info

# Wichtig für Pangolin/Reverse Proxy
export PROXY_TLS=false
export OCIS_INSECURE=true
export PROXY_HTTP_ADDR=0.0.0.0:9200

# Admin Setup
export IDM_ADMIN_PASSWORD=$ADMIN_PASSWORD

# Initiale Konfiguration erstellen, falls nicht vorhanden
if [ ! -f "$OCIS_CONFIG_DIR/ocis.yaml" ]; then
    echo "[INFO] Erstelle Initial-Konfiguration..."
    ocis init --insecure true
fi

# OpenCloud starten
exec ocis server
