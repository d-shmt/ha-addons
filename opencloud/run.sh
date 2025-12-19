#!/bin/bash
set -e

echo "--> Starting OpenCloud Add-on Setup..."

# 1. Konfiguration auslesen
DOMAIN=$(jq --raw-output '.domain' $CONFIG_PATH)
STORAGE_PATH=$(jq --raw-output '.storage_path' $CONFIG_PATH)

echo "--> Configuration loaded:"
echo "    Domain: $DOMAIN"
echo "    Storage: $STORAGE_PATH"

# 2. SICHERHEITS-CHECK: Prüfen, ob der Speicherpfad existiert
# Wenn nicht: ABBRUCH!
if [ ! -d "$STORAGE_PATH" ]; then
    echo "------------------------------------------------------------"
    echo "CRITICAL ERROR: Storage path NOT found!"
    echo "Path: $STORAGE_PATH"
    echo ""
    echo "Possible reasons:"
    echo "1. The NFS Share is not mounted in Home Assistant (Settings -> System -> Storage)."
    echo "2. The path in the add-on configuration is incorrect."
    echo ""
    echo "Aborting start to prevent data loss or writing to local disk."
    echo "------------------------------------------------------------"
    exit 1
fi

echo "--> Storage path found. Proceeding..."

# 3. Environment Variablen für OpenCloud setzen
export OC_SERVER_ROOT="/data"
export OC_SERVER_ADDRESS="0.0.0.0"
export OC_SERVER_PORT="9200"
export OC_URL="https://$DOMAIN"
export OC_INSECURE="true"

# Speicherort für die User-Daten (NFS Share)
export OC_STORAGE_LOCAL_ROOT="$STORAGE_PATH"

# Home Verzeichnis für OpenCloud interne Daten (DBs, Configs)
# Diese bleiben lokal im Container-Volume (/data), damit das Add-on schnell bleibt
export OC_BASE_DATA_PATH="/data"

echo "--> Checking/Initializing OpenCloud configuration..."
# Init, falls noch keine Config existiert
if [ ! -f "/data/opencloud.yaml" ]; then
    echo "--> No config found. Initializing..."
    opencloud init || true
fi

echo "--> Starting OpenCloud Server..."
echo "------------------------------------------------"

# Starten der Anwendung im Server-Modus
exec opencloud server
