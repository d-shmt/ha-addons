#!/bin/sh
set -e

# Helper Funktion für Logs mit Zeitstempel
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
    log "Bitte sicherstellen, dass das NAS in HA gemountet ist."
    exit 1
fi

# --- 3. UMGEBUNGSVARIABLEN SETZEN ---
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

# Netzwerk & Proxy
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export OC_URL="$OC_URL_VAL"
# Vertraue allen privaten Netzen (WICHTIG für Pangolin!)
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"

# DEBUG LOGGING (Neu!)
export OC_LOG_LEVEL="info"
export OC_LOG_COLOR="false"
export OC_LOG_PRETTY="false"

export IDM_ADMIN_PASSWORD="$ADMIN_PASS"

# --- 4. ORDNER VORBEREITEN ---
log "--> Bereite lokale Ordner vor..."
mkdir -p "$OC_BASE_DATA_PATH"
mkdir -p "$OC_CONFIG_DIR"

NAS_BLOBS="$NAS_PATH_VAL/blobs"
if [ ! -d "$NAS_BLOBS" ]; then
    log "--> Erstelle Blobs-Ordner auf dem NAS..."
    mkdir -p "$NAS_BLOBS"
fi

# --- 5. INITIALISIERUNG ---
# Rechte vor Init setzen
chown -R 1000:1000 "$OC_BASE_DATA_PATH" "$OC_CONFIG_DIR"

if [ ! -f "$OC_CONFIG_DIR/opencloud.yaml" ]; then
    log "--> Keine Config gefunden. Führe 'opencloud init' aus..."
    su-exec 1000:1000 opencloud init
else
    log "--> Config existiert bereits."
fi

# --- 6. DER STORAGE-HACK ---
INTERNAL_STORAGE_ROOT="$OC_BASE_DATA_PATH/storage/users"
INTERNAL_BLOBS_LINK="$INTERNAL_STORAGE_ROOT/blobs"

log "--> Konfiguriere Hybrid-Storage..."
mkdir -p "$INTERNAL_STORAGE_ROOT"

if [ -d "$INTERNAL_BLOBS_LINK" ] && [ ! -L "$INTERNAL_BLOBS_LINK" ]; then
    log "WARNUNG: Lokaler Blobs-Ordner gefunden. Lösche ihn..."
    rm -rf "$INTERNAL_BLOBS_LINK"
fi

if [ ! -L "$INTERNAL_BLOBS_LINK" ]; then
    log "--> Erstelle Symlink: Lokal -> NAS"
    ln -s "$NAS_BLOBS" "$INTERNAL_BLOBS_LINK"
fi

# --- 7. RECHTE-FIX ---
log "--> Korrigiere Dateirechte für User 1000..."
chown -hR 1000:1000 "$OC_BASE_DATA_PATH"
chown -R 1000:1000 "$OC_CONFIG_DIR"
chown -R 1000:1000 "$NAS_BLOBS" || true

# --- 8. START ---
log "--> Starte OpenCloud Server..."
echo "------------------------------------------------"

exec su-exec 1000:1000 opencloud server
