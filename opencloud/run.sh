#!/bin/sh
set -e

echo "--> Starte OpenCloud Add-on (Documentation Compliant Mode)..."

# --- CONFIG ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- VALIDIERUNG ---
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "FEHLER: NAS-Pfad $NAS_PATH_VAL nicht gefunden!"
    exit 1
fi

# --- PFADE DEFINIEREN ---
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

# WICHTIG: Das ist das Basis-Verzeichnis. 
# OCIS wird hier drin AUTOMATISCH einen Ordner 'users' erwarten/erstellen.
STORAGE_ROOT_BASE="/data/data/storage"

# Das ist der Ordner, wo die Daten wirklich liegen
# Wir bauen ihn manuell vor, damit der Symlink sitzt, bevor OCIS startet.
REAL_USERS_DIR="$STORAGE_ROOT_BASE/users"

# NAS Ziel
NAS_BLOBS="$NAS_PATH_VAL/blobs"

# Ordner erstellen
mkdir -p "$OC_CONFIG_DIR"
mkdir -p "$NAS_BLOBS"

# --- SYMLINK VORBEREITUNG (Der Trick) ---
echo "--> Bereite Hybrid-Storage Struktur vor..."

# 1. Wir erstellen das Verzeichnis, wo OCIS gleich reinschreiben will
mkdir -p "$REAL_USERS_DIR"

# 2. Wir definieren den Pfad, wo die Blobs (Dateien) landen sollen
LOCAL_BLOBS_LINK="$REAL_USERS_DIR/blobs"

# 3. Aufräumen: Falls dort ein echter Ordner ist (falsch), löschen
if [ -d "$LOCAL_BLOBS_LINK" ] && [ ! -L "$LOCAL_BLOBS_LINK" ]; then
    echo "ACHTUNG: Entferne lokalen Blob-Ordner, um Platz für Symlink zu schaffen..."
    rm -rf "$LOCAL_BLOBS_LINK"
fi

# 4. Symlink setzen: Wir zwingen die 'blobs' auf das NAS
if [ ! -L "$LOCAL_BLOBS_LINK" ]; then
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS_LINK"
    echo "--> Symlink gesetzt: $LOCAL_BLOBS_LINK -> $NAS_BLOBS"
else
    echo "--> Symlink existiert bereits korrekt."
fi

# --- RECHTE SETZEN ---
echo "--> Setze Rechte..."
# NAS Rechte
chown -R 1000:1000 "$NAS_BLOBS" || true
# Lokale Rechte (auch für den Symlink selbst mit -h)
chown -hR 1000:1000 /data/data
chown -R 1000:1000 /data/config

# --- UMGEBUNGSVARIABLEN ---
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"

# --- TREIBER CONFIG (Laut Doku) ---
export OC_STORAGE_USERS_DRIVER="ocis"
# WICHTIG: Wir zeigen auf das BASIS-Verzeichnis, nicht auf /users!
# OCIS macht daraus dann automatisch $STORAGE_ROOT_BASE/users
export OC_STORAGE_USERS_ROOT="$STORAGE_ROOT_BASE"

echo "--> Init & Start..."
su-exec 1000:1000 opencloud init || true
exec su-exec 1000:1000 opencloud server
