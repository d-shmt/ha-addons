#!/bin/sh
set -e

echo "--> Starte OpenCloud Add-on (Deep-Link Fix)..."

# --- CONFIG ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "FEHLER: NAS-Pfad $NAS_PATH_VAL nicht gefunden!"
    exit 1
fi

# --- PFADE ---
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

# 1. Wir sagen OpenCloud: "Hier ist dein Root"
# OpenCloud macht daraus AUTOMATISCH: /data/data/storage/users
export OC_STORAGE_USERS_ROOT="/data/data/storage"

# 2. Deshalb müssen wir den Symlink auch GENAU DORT bauen:
ACTUAL_DATA_DIR="/data/data/storage/users"
NAS_BLOBS="$NAS_PATH_VAL/blobs"

# Ordner vorbereiten
mkdir -p "$OC_CONFIG_DIR"
mkdir -p "$NAS_BLOBS"

# --- SYMLINK LOGIK ---
echo "--> Bereite Ordnerstruktur vor..."

# Wir erstellen den Ordner /users manuell, bevor OpenCloud es tut
mkdir -p "$ACTUAL_DATA_DIR"

# Der Pfad, wo der Link hin MUSS:
TARGET_LINK="$ACTUAL_DATA_DIR/blobs"

# Aufräumen: Falls dort schon ein echter Ordner ist -> Weg damit!
if [ -d "$TARGET_LINK" ] && [ ! -L "$TARGET_LINK" ]; then
    echo "ACHTUNG: Lösche lokalen Blob-Ordner $TARGET_LINK"
    rm -rf "$TARGET_LINK"
fi

# Symlink setzen
if [ ! -L "$TARGET_LINK" ]; then
    ln -s "$NAS_BLOBS" "$TARGET_LINK"
    echo "--> Symlink gesetzt: $TARGET_LINK -> $NAS_BLOBS"
else
    echo "--> Symlink existiert bereits."
fi

# --- RECHTE ---
echo "--> Setze Rechte..."
chown -R 1000:1000 "$NAS_BLOBS" || true
chown -hR 1000:1000 /data/data
chown -R 1000:1000 /data/config

# --- UMGEBUNGSVARIABLEN ---
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"
export OC_STORAGE_USERS_DRIVER="ocis"

echo "--> Init & Start..."
su-exec 1000:1000 opencloud init || true
exec su-exec 1000:1000 opencloud server
