#!/bin/sh
set -e

echo "--> Starte OpenCloud Add-on (Split Storage Mode)..."

# --- 1. KONFIGURATION LESEN ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- 2. PFADE DEFINIEREN ---
export OC_CONFIG_DIR="/data/config"
export OC_BASE_DATA_PATH="/data/data"
NAS_BLOBS="$NAS_PATH_VAL/blobs"

# --- 3. VALIDIERUNG NAS ---
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "FEHLER: Der NAS-Pfad $NAS_PATH_VAL wurde nicht gefunden!"
    exit 1
fi

echo "--> Richte Ordnerstruktur ein..."
mkdir -p "$OC_CONFIG_DIR"
mkdir -p "$OC_BASE_DATA_PATH"

if [ ! -d "$NAS_BLOBS" ]; then
    echo "--> Erstelle Blobs-Ordner auf dem NAS ($NAS_BLOBS)..."
    mkdir -p "$NAS_BLOBS"
fi

# Rechteversuch (Fehler ignorieren)
chown -R 1000:1000 "$NAS_BLOBS" || true

# --- 4. UMGEBUNGSVARIABLEN SETZEN ---
echo "--> Setze OpenCloud Environment..."
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"
export OC_CONFIG_DIR=$OC_CONFIG_DIR
export OC_BASE_DATA_PATH=$OC_BASE_DATA_PATH

# --- 5. INITIALISIERUNG (FIX FÜR ABSTURZ) ---
chown -R 1000:1000 /data

# Wir prüfen grob auf Existenz, aber fangen Fehler ab
if [ ! -f "$OC_CONFIG_DIR/ocis.yaml" ]; then
    echo "--> Erstelle initiale Konfiguration..."
    # WICHTIG: '|| true' verhindert den Absturz, falls init meckert
    su-exec 1000:1000 opencloud init || true
else
    echo "--> Konfiguration bereits vorhanden."
fi

# --- 6. SYMLINK LOGIK (FIX FÜR LEEREN NAS ORDNER) ---
echo "--> Verlinke lokalen Storage zum NAS..."
LOCAL_STORAGE_USERS="$OC_BASE_DATA_PATH/storage/users"
LOCAL_BLOBS="$LOCAL_STORAGE_USERS/blobs"

# Ordnerstruktur vorbereiten
mkdir -p "$LOCAL_STORAGE_USERS"
chown -R 1000:1000 "$OC_BASE_DATA_PATH"

# Falls "blobs" lokal existiert und KEIN Link ist -> Weg damit!
if [ -d "$LOCAL_BLOBS" ] && [ ! -L "$LOCAL_BLOBS" ]; then
    echo "WARNUNG: Lokaler Blobs-Ordner gefunden. Lösche ihn für NAS-Link..."
    rm -rf "$LOCAL_BLOBS"
fi

# Symlink erstellen
if [ ! -L "$LOCAL_BLOBS" ]; then
    echo "--> Erstelle Symlink: Intern -> NAS..."
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS"
    # Rechte des Links selbst anpassen (-h)
    chown -h 1000:1000 "$LOCAL_BLOBS"
fi

# --- 7. FINALER START ---
echo "--> Starte OpenCloud Server..."
exec su-exec 1000:1000 opencloud server
