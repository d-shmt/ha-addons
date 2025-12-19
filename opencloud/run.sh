#!/bin/sh
set -e

# Helper Funktion für Logs
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

log "--> Starte OpenCloud Add-on Setup (Final Fix)..."

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

# --- 3. UMGEBUNGSVARIABLEN ---
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

# Netzwerk & Proxy (Vertrauen für Pangolin)
export OC_INSECURE=true
export OCIS_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"

export OC_URL="$OC_URL_VAL"
export OCIS_URL="$OC_URL_VAL"
export IDP_ISSUER_URL="$OC_URL_VAL"

# Vertraue ALLEN Proxies (Löst den 500er Fehler)
export PROXY_TRUSTED_PROXIES="0.0.0.0/0"
export OCIS_TRUSTED_PROXIES="0.0.0.0/0"
export OC_TRUSTED_PROXIES="0.0.0.0/0"
export TRUSTED_PROXIES="0.0.0.0/0"

export IDM_ADMIN_PASSWORD="$ADMIN_PASS"

# Logging auf INFO (Panic ist weg, wir wollen normalen Betrieb sehen)
export OC_LOG_LEVEL="info"
export OC_LOG_COLOR="false"
export OC_LOG_PRETTY="false"

# --- 4. ORDNER & RECHTE (Der Fix für den Crash) ---
log "--> Bereite Ordnerstruktur vor..."

# Wir erstellen ALLE Ordner, die OpenCloud braucht, manuell vorab.
# Das verhindert, dass OpenCloud versucht, sie selbst anzulegen und scheitert.
mkdir -p "$OC_BASE_DATA_PATH"
mkdir -p "$OC_CONFIG_DIR"
mkdir -p "$OC_BASE_DATA_PATH/storage"
mkdir -p "$OC_BASE_DATA_PATH/storage/users"
mkdir -p "$OC_BASE_DATA_PATH/storage/ocm"       # <--- WICHTIG: Fix für den ocm-Crash
mkdir -p "$OC_BASE_DATA_PATH/storage/metadata"  # Prophylaktisch

NAS_BLOBS="$NAS_PATH_VAL/blobs"
mkdir -p "$NAS_BLOBS"

# --- 5. INITIALISIERUNG ---
# Rechte für Config-Ordner setzen, damit init schreiben darf
chown -R 1000:1000 "$OC_CONFIG_DIR" "$OC_BASE_DATA_PATH"

if [ ! -f "$OC_CONFIG_DIR/opencloud.yaml" ]; then
    log "--> Führe 'opencloud init' aus..."
    su-exec 1000:1000 opencloud init
else
    log "--> Config existiert bereits."
fi

# --- 6. STORAGE SYMLINK ---
INTERNAL_STORAGE_ROOT="$OC_BASE_DATA_PATH/storage/users"
INTERNAL_BLOBS_LINK="$INTERNAL_STORAGE_ROOT/blobs"

# Link sauber neu setzen
if [ -d "$INTERNAL_BLOBS_LINK" ] && [ ! -L "$INTERNAL_BLOBS_LINK" ]; then
    rm -rf "$INTERNAL_BLOBS_LINK"
fi

if [ ! -L "$INTERNAL_BLOBS_LINK" ]; then
    log "--> Erstelle Symlink zum NAS..."
    ln -s "$NAS_BLOBS" "$INTERNAL_BLOBS_LINK"
fi

# --- 7. FINALER RECHTE-FIX ---
log "--> Korrigiere Dateirechte für User 1000..."
# Wir zwingen ALLES in /data auf User 1000.
# Das stellt sicher, dass auch der manuell erstellte 'ocm' Ordner beschreibbar ist.
chown -hR 1000:1000 "/data/data"
chown -R 1000:1000 "/data/config"
chown -R 1000:1000 "$NAS_BLOBS" || true

# --- 8. START ---
log "--> Starte OpenCloud Server..."
echo "------------------------------------------------"
exec su-exec 1000:1000 opencloud server
