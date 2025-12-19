#!/bin/sh
set -e

echo "--> Starte OpenCloud Add-on (Fixed Hybrid Mode)..."

# --- KONFIGURATION LESEN ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- VALIDIERUNG ---
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "FEHLER: Der Pfad $NAS_PATH_VAL existiert nicht auf dem NAS!"
    exit 1
fi

# --- ORDNER VORBEREITEN ---
# Wir definieren harte Pfade, um Verwirrung zu vermeiden
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

mkdir -p $OC_BASE_DATA_PATH
mkdir -p $OC_CONFIG_DIR

# NAS Blobs Ordner vorbereiten
NAS_BLOBS="$NAS_PATH_VAL/blobs"
if [ ! -d "$NAS_BLOBS" ]; then
    echo "--> Erstelle Blobs-Ordner auf dem NAS..."
    mkdir -p "$NAS_BLOBS"
fi
chown -R 1000:1000 "$NAS_BLOBS" || true

# --- UMGEBUNGSVARIABLEN ---
echo "--> Setze Umgebungsvariablen..."

# 1. SSL & Netzwerk
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"

# 2. OCIS Basis
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"

# 3. STORAGE TREIBER (Der wichtige Fix!)
# Wir zwingen OCIS, genau diesen Pfad als Root für User-Daten zu nehmen.
# Damit verhindern wir das "users/users" Problem.
export OC_STORAGE_USERS_DRIVER="ocis"
export OC_STORAGE_USERS_ROOT="/data/data/storage"

# --- SYMLINK LOGIK (Der "Trick") ---
echo "--> Verlinke Blob-Speicher zum NAS..."

# Der lokale Ordner, wo OCIS die Daten erwartet
LOCAL_STORAGE_ROOT="/data/data/storage/users"
LOCAL_BLOBS="$LOCAL_STORAGE_ROOT/blobs"

# 1. Stelle sicher, dass der Elternordner existiert
mkdir -p "$LOCAL_STORAGE_ROOT"

# 2. Prüfen: Existiert der 'blobs' Ordner schon und ist KEIN Symlink?
# (Das passiert, wenn OCIS aus Versehen lokal geschrieben hat)
if [ -d "$LOCAL_BLOBS" ] && [ ! -L "$LOCAL_BLOBS" ]; then
    echo "ACHTUNG: Lokaler 'blobs' Ordner gefunden. Versuche zu bereinigen..."
    # Nur löschen, wenn er leer ist (Sicherheitsmaßnahme)
    rmdir "$LOCAL_BLOBS" 2>/dev/null || echo "WARNUNG: Lokaler Blobs-Ordner ist nicht leer! Bitte manuell prüfen."
fi

# 3. Symlink setzen (nur wenn er noch nicht da ist)
if [ ! -L "$LOCAL_BLOBS" ]; then
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS"
    echo "--> Symlink erfolgreich gesetzt: $LOCAL_BLOBS -> $NAS_BLOBS"
else
    echo "--> Symlink existiert bereits."
fi

# --- INIT & START ---
echo "--> Rechte setzen..."
# Wichtig: -h ändert den Symlink-Eigentümer, nicht das NAS selbst (Performance)
chown -hR 1000:1000 /data/data
chown -R 1000:1000 /data/config

echo "--> Initialisiere OpenCloud..."
su-exec 1000:1000 opencloud init || true

echo "--> Starte OpenCloud Server..."
exec su-exec 1000:1000 opencloud server
