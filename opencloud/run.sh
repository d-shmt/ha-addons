#!/bin/bash
set -e

echo "--> Starting OpenCloud Add-on Setup..."

# 1. Konfiguration auslesen
DOMAIN=$(jq --raw-output '.domain' $CONFIG_PATH)
STORAGE_PATH=$(jq --raw-output '.storage_path' $CONFIG_PATH)

echo "--> Configuration loaded:"
echo "    Domain: $DOMAIN"
echo "    Storage: $STORAGE_PATH"

# 2. SICHERHEITS-CHECK: Speicherpfad
if [ ! -d "$STORAGE_PATH" ]; then
    echo "------------------------------------------------------------"
    echo "CRITICAL ERROR: Storage path NOT found!"
    echo "Path: $STORAGE_PATH"
    echo "Aborting start to prevent data loss."
    echo "------------------------------------------------------------"
    exit 1
fi

# 3. JWT SECRET MANAGMENT (Fix für den Fehler)
# Wir brauchen ein persistentes Secret für die interne Kommunikation
JWT_SECRET_FILE="/data/oc_jwt_secret"

if [ ! -f "$JWT_SECRET_FILE" ]; then
    echo "--> No JWT secret found. Generating a new one..."
    # Erzeugt einen 32-Zeichen zufälligen String
    tr -dc A-Za-z0-9 </dev/urandom | head -c 32 > "$JWT_SECRET_FILE"
fi

# Secret in Variable laden
export OC_JWT_SECRET=$(cat "$JWT_SECRET_FILE")


# 4. Environment Variablen für OpenCloud setzen
export OC_SERVER_ROOT="/data"
export OC_SERVER_ADDRESS="0.0.0.0"
export OC_SERVER_PORT="9200"
export OC_URL="https://$DOMAIN"
export OC_INSECURE="true"
export OC_STORAGE_LOCAL_ROOT="$STORAGE_PATH"
export OC_BASE_DATA_PATH="/data"

# Explizit den Pfad zur Config Datei setzen, damit er sie sicher findet
export OC_CONFIG_FILE="/data/opencloud.yaml"

echo "--> Checking/Initializing OpenCloud configuration..."
# Init, falls noch keine Config existiert
if [ ! -f "/data/opencloud.yaml" ]; then
    echo "--> No config found. Initializing..."
    opencloud init || true
fi

echo "--> Starting OpenCloud Server..."
echo "------------------------------------------------"

# Starten
exec opencloud server
