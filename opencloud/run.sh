#!/bin/bash
set -e

echo "--> Starting OpenCloud Add-on Setup..."

# 1. Konfiguration auslesen
# Wir lesen die Werte, die der User in HA eingestellt hat
DOMAIN=$(jq --raw-output '.domain' $CONFIG_PATH)
STORAGE_PATH=$(jq --raw-output '.storage_path' $CONFIG_PATH)

echo "--> Configuration loaded:"
echo "    Domain: $DOMAIN"
echo "    Storage: $STORAGE_PATH"

# 2. Prüfen, ob der Speicherpfad existiert
if [ ! -d "$STORAGE_PATH" ]; then
    echo "--> WARNING: Storage path $STORAGE_PATH does not exist!"
    echo "--> Creating it now..."
    mkdir -p "$STORAGE_PATH"
fi

# 3. Environment Variablen für OpenCloud setzen
# Wir nutzen die Config von HA (/data), damit Einstellungen erhalten bleiben
export OC_SERVER_ROOT="/data"
export OC_SERVER_ADDRESS="0.0.0.0"
export OC_SERVER_PORT="9200"
export OC_SERVER_URL="https://$DOMAIN"
export OC_INSECURE="true" # Wichtig für Pangolin (SSL offloading)

# Speicherort für die Dateien setzen (NFS Share)
# OpenCloud nutzt standardmäßig 'local' storage driver. Wir biegen das Root-Verzeichnis um.
export OC_STORAGE_LOCAL_ROOT="$STORAGE_PATH"

echo "--> Starting OpenCloud..."
echo "------------------------------------------------"

# Starten der Anwendung (als der User, der im Original-Image definiert ist, oder root)
# Da wir im Dockerfile root sind, starten wir es einfach.
exec opencloud
