#!/bin/sh
set -e

# Helper Funktion für Logs
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

log "--> Starte OpenCloud Add-on Setup (Hybrid Mode)..."

# --- 1. CONFIG LESEN ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

log "--> Einstellungen geladen:"
log "    URL: $OC_URL_VAL"
log "    NAS Pfad: $NAS_PATH_VAL"

# --- 2. VALIDIERUNG ---
if [ ! -d "$NAS_PATH_VAL" ]; then
    log "CRITICAL ERROR: Der Pfad $NAS_PATH_VAL existiert nicht!"
    exit 1
fi

# --- 3. UMGEBUNGSVARIABLEN (Maximales Vertrauen) ---
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

# Netzwerk Basics
export OC_INSECURE=true
export OCIS_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"

# URL Konfiguration
export OC_URL="$OC_URL_VAL"
export OCIS_URL="$OC_URL_VAL"
export IDP_ISSUER_URL="$OC_URL_VAL"

# --- PROXY VERTRAUEN (Die Schrotflinte) ---
# Wir setzen jede erdenkliche Variable, damit OpenCloud dem Proxy vertraut.
# CIDR 0.0.0.0/0 bedeutet "Vertraue jedem" (notwendig im Docker-Netzwerk).

export PROXY_TRUSTED_PROXIES="0.0.0.0/0"
export OCIS_TRUSTED_PROXIES="0.0.0.0/0"
export OC_TRUSTED_PROXIES="0.0.0.0/0"
export TRUSTED_PROXIES="0.0.0.0/0"

# Admin User
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"

# DEBUG LOGGING (WICHTIG!)
# Wir brauchen Debug, um den Grund für den 500er Fehler zu sehen.
export OC_LOG_LEVEL="debug"
export OCIS_LOG_LEVEL="debug"
export OC_LOG_COLOR="false"
export OC_LOG_PRETTY="false"

# --- 4. ORDNER & RECHTE ---
log "--> Bereite Ordner vor..."
mkdir -p "$OC_BASE_DATA_PATH" "$OC_CONFIG_DIR"
NAS_BLOBS="$NAS_PATH_VAL/blobs"
mkdir -p "$NAS_BLOBS"

# Rechte setzen (User 1000)
chown -R 1000:1000 "$OC_BASE_DATA_PATH" "$OC_CONFIG_DIR"
chown -R 1000:1000 "$NAS_BLOBS" || true

# --- 5. INITIALISIERUNG ---
if [ ! -f "$OC_CONFIG_DIR/opencloud.yaml" ]; then
    log "--> Führe 'opencloud init' aus..."
    su-exec 1000:1000 opencloud init
else
    log "--> Config existiert bereits."
fi

# --- 6. STORAGE SYMLINK ---
INTERNAL_STORAGE_ROOT="$OC_BASE_DATA_PATH/storage/users"
INTERNAL_BLOBS_LINK="$INTERNAL_STORAGE_ROOT/blobs"

mkdir -p "$INTERNAL_STORAGE_ROOT"
chown 1000:1000 "$INTERNAL_STORAGE_ROOT"

if [ -d "$INTERNAL_BLOBS_LINK" ] && [ ! -L "$INTERNAL_BLOBS_LINK" ]; then
    rm -rf "$INTERNAL_BLOBS_LINK"
fi

if [ ! -L "$INTERNAL_BLOBS_LINK" ]; then
    log "--> Erstelle Symlink zum NAS..."
    ln -s "$NAS_BLOBS" "$INTERNAL_BLOBS_LINK"
    chown -h 1000:1000 "$INTERNAL_BLOBS_LINK"
fi

# --- 7. START ---
log "--> Starte OpenCloud Server..."
echo "------------------------------------------------"
exec su-exec 1000:1000 opencloud server
