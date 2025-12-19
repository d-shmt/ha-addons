#!/bin/sh
set -e

echo "--> Starte OpenCloud Add-on (Split Storage Mode)..."

# --- 1. KONFIGURATION LESEN ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- 2. PFADE DEFINIEREN ---
# Interner Speicher (Home Assistant /data ist persistent und wird gebackupt)
export OC_CONFIG_DIR="/data/config"
export OC_BASE_DATA_PATH="/data/data"

# Pfad für die eigentlichen Dateien auf dem NAS
NAS_BLOBS="$NAS_PATH_VAL/blobs"

# --- 3. VALIDIERUNG NAS ---
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "FEHLER: Der NAS-Pfad $NAS_PATH_VAL wurde nicht gefunden!"
    echo "Bitte prüfe, ob das NAS in Home Assistant unter 'Speicher' gemountet ist."
    exit 1
fi

echo "--> Richte Ordnerstruktur ein..."
# Lokale Ordner erstellen
mkdir -p "$OC_CONFIG_DIR"
mkdir -p "$OC_BASE_DATA_PATH"

# NAS Ordner erstellen, falls nicht vorhanden
if [ ! -d "$NAS_BLOBS" ]; then
    echo "--> Erstelle Blobs-Ordner auf dem NAS ($NAS_BLOBS)..."
    mkdir -p "$NAS_BLOBS"
fi

# Rechte auf NAS anpassen (Versuch, Fehler werden ignoriert falls SMB das nicht erlaubt)
chown -R 1000:1000 "$NAS_BLOBS" || echo "WARNUNG: Konnte Rechte auf NAS nicht setzen (bei SMB normal)."

# --- 4. UMGEBUNGSVARIABLEN SETZEN ---
echo "--> Setze OpenCloud Environment..."

# Sicherheit & Proxy
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"

# Admin & URL
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"

# WICHTIG: Explizite Pfad-Zuweisung für OCIS
export OC_CONFIG_DIR=$OC_CONFIG_DIR
export OC_BASE_DATA_PATH=$OC_BASE_DATA_PATH

# --- 5. INITIALISIERUNG ---
# Zuerst Rechte für lokalen Ordner fixen, damit 'init' schreiben darf
chown -R 1000:1000 /data

if [ ! -f "$OC_CONFIG_DIR/ocis.yaml" ]; then
    echo "--> Erstelle initiale Konfiguration..."
    su-exec 1000:1000 opencloud init
else
    echo "--> Konfiguration gefunden."
fi

# --- 6. SYMLINK MAGIE (Intern -> NAS) ---
# Wir verlinken NUR den 'blobs' Ordner.
# Metadata bleibt lokal (schnell + sicher), Dateien gehen aufs NAS (groß).
LOCAL_STORAGE_USERS="$OC_BASE_DATA_PATH/storage/users"
LOCAL_BLOBS="$LOCAL_STORAGE_USERS/blobs"

# Parent Ordnerstruktur sicherstellen
mkdir -p "$LOCAL_STORAGE_USERS"
chown -R 1000:1000 "$OC_BASE_DATA_PATH"

# Falls dort schon ein echter Ordner "blobs" ist (kein Link) und er leer ist -> löschen
if [ -d "$LOCAL_BLOBS" ] && [ ! -L "$LOCAL_BLOBS" ]; then
    # Nur löschen wenn leer, um Datenverlust zu vermeiden
    rmdir "$LOCAL_BLOBS" 2>/dev/null || true
fi

# Symlink erstellen
if [ ! -L "$LOCAL_BLOBS" ]; then
    echo "--> Erstelle Symlink: Intern -> NAS..."
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS"
fi

# --- 7. FINALER START ---
echo "--> Korrigiere Dateirechte (Lokal)..."
# -h ändert den Besitzer des Links selbst, nicht des Ziels (wichtig bei NAS)
chown -hR 1000:1000 /data

echo "--> Starte OpenCloud Server..."
exec su-exec 1000:1000 opencloud server
