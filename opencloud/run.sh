#!/bin/sh
set -e

echo "--> Starte OpenCloud Add-on (Hybrid Storage Mode)..."

# --- KONFIGURATION LESEN ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- VALIDIERUNG ---
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "FEHLER: Der Pfad $NAS_PATH_VAL existiert nicht!"
    exit 1
fi

# --- ORDNER VORBEREITEN ---
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

# Lokale Basisordner
mkdir -p $OC_BASE_DATA_PATH
mkdir -p $OC_CONFIG_DIR

# NAS Blobs Ordner
NAS_BLOBS="$NAS_PATH_VAL/blobs"
if [ ! -d "$NAS_BLOBS" ]; then
    echo "--> Erstelle Blobs-Ordner auf dem NAS..."
    mkdir -p "$NAS_BLOBS"
fi
# NAS Rechte versuchen (Fehler ignorieren)
chown -R 1000:1000 "$NAS_BLOBS" || true

# --- VARIABLES ---
echo "--> Setze Umgebungsvariablen..."

# 1. SSL-Terminierung: Intern nur unverschlüsseltes HTTP sprechen
export OC_INSECURE=true
export PROXY_TLS=false

# 2. Die wichtigsten OCIS Einstellungen
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"
export PROXY_HTTP_ADDR="0.0.0.0:9200"

# 3. VERTRAUENS-EINSTELLUNGEN (Wichtig für Pangolin!)
# Wir vertrauen ALLEN privaten Netzwerken. Das verhindert den 400er Fehler,
# wenn Pangolin Header wie "X-Forwarded-For" sendet.
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"

# 4. Hybrid-Storage Pfade
export OC_CONFIG_DIR="/data/config"
export OC_BASE_DATA_PATH="/data/data"

echo "--> Initialisiere OpenCloud Config..."
# Config erstellen, falls noch nicht vorhanden
# Wir machen vorher chown, damit init schreiben darf
chown -R 1000:1000 /data/data /data/config
su-exec 1000:1000 opencloud init || true

# --- SYMLINK LOGIK ---
echo "--> Verlinke lokalen Storage zum NAS..."
LOCAL_STORAGE_USERS="/data/data/storage/users"
LOCAL_BLOBS="$LOCAL_STORAGE_USERS/blobs"

# Parent Struktur erstellen
mkdir -p "$LOCAL_STORAGE_USERS"

# Leeren Blobs Ordner entfernen, falls er existiert und kein Link ist
if [ -d "$LOCAL_BLOBS" ] && [ ! -L "$LOCAL_BLOBS" ]; then
    rmdir "$LOCAL_BLOBS" || true
fi

# Symlink setzen
if [ ! -L "$LOCAL_BLOBS" ]; then
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS"
    echo "--> Symlink erstellt."
fi

# --- FINALER RECHTE-FIX (WICHTIG!) ---
echo "--> Korrigiere Dateirechte..."
# Wir zwingen ALLES in /data/data auf User 1000.
# Das behebt den "permission denied" Fehler beim Erstellen von 'metadata'.
# Wichtig: -h damit wir den Symlink selbst ändern, nicht das Ziel (NAS)
chown -hR 1000:1000 /data/data
chown -R 1000:1000 /data/config

echo "--> Starte OpenCloud Server..."
exec su-exec 1000:1000 opencloud server