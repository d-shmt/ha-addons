#!/bin/sh
set -e

echo "--> Starte OpenCloud (Force-NAS Mode)..."

# --- CONFIG ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- PFADE ---
export OC_CONFIG_DIR="/data/config"
export OC_BASE_DATA_PATH="/data/data"
NAS_BLOBS="$NAS_PATH_VAL/blobs"

# --- 1. NAS CHECK ---
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "FEHLER: NAS-Pfad $NAS_PATH_VAL nicht gefunden!"
    exit 1
fi

# NAS-Ordner erstellen (falls fehlt)
# Wir verlassen uns auf dein 'chmod 777' auf dem Host!
if [ ! -d "$NAS_BLOBS" ]; then
    echo "--> Erstelle NAS-Ordner..."
    mkdir -p "$NAS_BLOBS"
fi

# --- 2. LOKALE STRUKTUR VORBEREITEN ---
echo "--> Bereite lokale Pfade vor..."
# Wir erstellen den Eltern-Ordner manuell, damit wir den Link reinlegen können
LOCAL_STORAGE_USERS="$OC_BASE_DATA_PATH/storage/users"
LOCAL_BLOBS="$LOCAL_STORAGE_USERS/blobs"

mkdir -p "$OC_CONFIG_DIR"
mkdir -p "$LOCAL_STORAGE_USERS" # Wichtig: Nur bis 'users' erstellen!

# --- 3. SYMLINK ERZWINGEN (DER FIX) ---
# Wir prüfen: Ist dort ein Ordner, der KEIN Link ist? -> Weg damit!
if [ -d "$LOCAL_BLOBS" ] && [ ! -L "$LOCAL_BLOBS" ]; then
    echo "ACHTUNG: Lokaler Blobs-Ordner entdeckt. Lösche ihn, um NAS zu erzwingen..."
    rm -rf "$LOCAL_BLOBS"
fi

# Link erstellen, falls nicht vorhanden
if [ ! -L "$LOCAL_BLOBS" ]; then
    echo "--> Erstelle Symlink: Intern -> NAS..."
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS"
else
    echo "--> Symlink ist bereits korrekt gesetzt."
fi

# WICHTIG: Rechte des Links (nicht des Ziels) anpassen
chown -h 1000:1000 "$LOCAL_BLOBS"
# Rechte für den Rest lokal setzen
chown -R 1000:1000 /data/data /data/config

# --- 4. ENV & START ---
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"
# Explizite Pfade für OCIS
export OC_CONFIG_DIR=$OC_CONFIG_DIR
export OC_BASE_DATA_PATH=$OC_BASE_DATA_PATH

echo "--> Initialisiere OpenCloud..."
# Jetzt darf init laufen - es wird den Symlink finden und nutzen!
su-exec 1000:1000 opencloud init || true

echo "--> Starte Server..."
exec su-exec 1000:1000 opencloud server
