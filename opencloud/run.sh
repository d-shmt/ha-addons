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
# Pfade intern (Lokal auf SSD für Performance)
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

# Netzwerk & Proxy (Pangolin Setup)
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export OC_URL="$OC_URL_VAL"
# Vertraue allen internen Netzen (Docker, LAN, Localhost) für Proxy-Header
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"

# Admin User (wird beim init verwendet)
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"

# --- 4. ORDNER VORBEREITEN ---
log "--> Bereite lokale Ordner vor..."
mkdir -p "$OC_BASE_DATA_PATH"
mkdir -p "$OC_CONFIG_DIR"

# NAS Ordner für die großen Dateien (Blobs)
NAS_BLOBS="$NAS_PATH_VAL/blobs"
if [ ! -d "$NAS_BLOBS" ]; then
    log "--> Erstelle Blobs-Ordner auf dem NAS..."
    mkdir -p "$NAS_BLOBS"
fi

# Rechte setzen (Wir sind aktuell noch root)
# Wir versuchen das NAS auf 1000 zu setzen. Wenn das NFS das blockt (Root Squash),
# ignorieren wir den Fehler mit '|| true', hoffen aber, dass User 1000 schreiben darf.
chown -R 1000:1000 "$OC_BASE_DATA_PATH" "$OC_CONFIG_DIR"
chown -R 1000:1000 "$NAS_BLOBS" || true

# --- 5. INITIALISIERUNG ---
if [ ! -f "$OC_CONFIG_DIR/opencloud.yaml" ]; then
    log "--> Keine Config gefunden. Führe 'opencloud init' aus..."
    # Wir führen init als User 1000 aus!
    su-exec 1000:1000 opencloud init
else
    log "--> Config existiert bereits."
fi

# --- 6. DER STORAGE-HACK (Symlink) ---
# OpenCloud speichert Dateien standardmäßig unter: $OC_BASE_DATA_PATH/storage/users/blobs
# Wir biegen diesen 'blobs' Ordner auf das NAS um.

INTERNAL_STORAGE_ROOT="$OC_BASE_DATA_PATH/storage/users"
INTERNAL_BLOBS_LINK="$INTERNAL_STORAGE_ROOT/blobs"

log "--> Konfiguriere Hybrid-Storage..."

# Stelle sicher, dass der Eltern-Ordner existiert (wichtig beim ersten Start!)
mkdir -p "$INTERNAL_STORAGE_ROOT"
chown 1000:1000 "$INTERNAL_STORAGE_ROOT"

# Prüfen, ob dort schon ein 'echter' Ordner ist (falsch) oder ein Link (richtig)
if [ -d "$INTERNAL_BLOBS_LINK" ] && [ ! -L "$INTERNAL_BLOBS_LINK" ]; then
    log "WARNUNG: Lokaler Blobs-Ordner gefunden. Lösche ihn, um Platz für Symlink zu machen..."
    # Vorsicht: Das löscht Daten, die versehentlich lokal gelandet sind!
    rm -rf "$INTERNAL_BLOBS_LINK"
fi

# Symlink erstellen, falls noch nicht da
if [ ! -L "$INTERNAL_BLOBS_LINK" ]; then
    log "--> Erstelle Symlink: Lokal -> NAS"
    ln -s "$NAS_BLOBS" "$INTERNAL_BLOBS_LINK"
    # Eigentümer des Links anpassen (User 1000)
    chown -h 1000:1000 "$INTERNAL_BLOBS_LINK"
else
    log "--> Symlink zum NAS ist bereits aktiv."
fi

# --- 7. START ---
log "--> Starte OpenCloud Server..."
echo "------------------------------------------------"

# Start als User 1000
exec su-exec 1000:1000 opencloud server
