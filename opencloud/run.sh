#!/bin/sh
set -e

echo "--> Starte OpenCloud Add-on (Immich-Style Compatibility)..."

# --- CONFIG ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- PFADE ---
export OC_CONFIG_DIR="/data/config"
export OC_BASE_DATA_PATH="/data/data"
NAS_BLOBS="$NAS_PATH_VAL/blobs"

# --- CHECK ---
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "FEHLER: NAS-Pfad nicht gefunden! Ist das NAS in HA gemountet?"
    exit 1
fi

# Ordnerstruktur erstellen (Lokal)
mkdir -p "$OC_CONFIG_DIR"
mkdir -p "$OC_BASE_DATA_PATH"

# NAS Ordner erstellen (versuchen, falls nicht existiert)
if [ ! -d "$NAS_BLOBS" ]; then
    echo "--> Erstelle Blobs-Ordner auf dem NAS..."
    mkdir -p "$NAS_BLOBS" || echo "WARNUNG: Konnte NAS-Ordner nicht erstellen (evtl. schon da?)"
fi

# WICHTIG: Wir machen KEIN chown auf dem NAS. 
# Wir verlassen uns darauf, dass der Ordner auf Proxmox 'chmod 777' hat.

# --- ENV ---
echo "--> Setze Environment..."
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"
export OC_CONFIG_DIR=$OC_CONFIG_DIR
export OC_BASE_DATA_PATH=$OC_BASE_DATA_PATH

# --- INIT ---
# Lokale Rechte fixen (das darf root immer)
chown -R 1000:1000 /data

if [ ! -f "$OC_CONFIG_DIR/ocis.yaml" ]; then
    echo "--> Init OpenCloud..."
    su-exec 1000:1000 opencloud init || true
fi

# --- SYMLINK ---
echo "--> Verlinke Storage..."
LOCAL_STORAGE_USERS="$OC_BASE_DATA_PATH/storage/users"
LOCAL_BLOBS="$LOCAL_STORAGE_USERS/blobs"

mkdir -p "$LOCAL_STORAGE_USERS"
chown -R 1000:1000 "$OC_BASE_DATA_PATH"

# Alten lokalen Ordner entfernen
if [ -d "$LOCAL_BLOBS" ] && [ ! -L "$LOCAL_BLOBS" ]; then
    echo "--> Entferne lokalen Blobs-Ordner für Link..."
    rm -rf "$LOCAL_BLOBS"
fi

# Link setzen
if [ ! -L "$LOCAL_BLOBS" ]; then
    echo "--> Erstelle Link zu $NAS_BLOBS"
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS"
    chown -h 1000:1000 "$LOCAL_BLOBS"
fi

echo "--> Starte Server..."
exec su-exec 1000:1000 opencloud server
