#!/bin/sh
set -e

echo "--> Starte OpenCloud Add-on (Clean Hybrid Mode)..."

# --- CONFIG ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- NAS CHECK ---
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "FEHLER: NAS-Pfad $NAS_PATH_VAL nicht gefunden!"
    exit 1
fi

# --- DEFINITIONEN ---
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

# Das ist der lokale Ordner, wo die Datenbank hinkommt
# WICHTIG: Wir nehmen das /users am Ende weg, damit die Struktur passt!
LOCAL_STORAGE_ROOT="/data/data/storage"

# Das ist der NAS Ordner
NAS_BLOBS="$NAS_PATH_VAL/blobs"

# Ordner erstellen
mkdir -p "$LOCAL_STORAGE_ROOT"
mkdir -p "$OC_CONFIG_DIR"
mkdir -p "$NAS_BLOBS"
chown -R 1000:1000 "$NAS_BLOBS" || true

# --- UMGEBUNGSVARIABLEN ---
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"

# WICHTIG: Damit zwingen wir OCIS in die richtige Struktur
export OC_STORAGE_USERS_DRIVER="ocis"
export OC_STORAGE_USERS_ROOT="$LOCAL_STORAGE_ROOT"

# --- SYMLINK MAGIE ---
echo "--> Richte Symlink ein..."
LOCAL_BLOBS="$LOCAL_STORAGE_ROOT/blobs"

# Falls ein "echter" Ordner blobs existiert (falsch), löschen wir ihn
if [ -d "$LOCAL_BLOBS" ] && [ ! -L "$LOCAL_BLOBS" ]; then
    echo "ACHTUNG: Lokaler Blobs-Ordner gefunden. Lösche ihn für Symlink..."
    rm -rf "$LOCAL_BLOBS"
fi

# Symlink setzen
if [ ! -L "$LOCAL_BLOBS" ]; then
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS"
    echo "--> Symlink erstellt: $LOCAL_BLOBS -> $NAS_BLOBS"
else
    echo "--> Symlink ist bereits korrekt."
fi

# --- START ---
echo "--> Fixiere Rechte..."
chown -hR 1000:1000 /data/data
chown -R 1000:1000 /data/config

echo "--> Init & Start..."
su-exec 1000:1000 opencloud init || true
exec su-exec 1000:1000 opencloud server
