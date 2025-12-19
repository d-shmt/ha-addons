#!/bin/bash
set -e

# Funktion für Log-Ausgaben mit Zeitstempel [HH:MM:SS]
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

log "--> Starting OpenCloud Add-on Setup..."

# 1. Konfiguration auslesen
DOMAIN=$(jq --raw-output '.domain' $CONFIG_PATH)
STORAGE_PATH=$(jq --raw-output '.storage_path' $CONFIG_PATH)

log "--> Configuration loaded:"
log "    Domain: $DOMAIN"
log "    Storage: $STORAGE_PATH"

# 2. SICHERHEITS-CHECK: Speicherpfad
if [ ! -d "$STORAGE_PATH" ]; then
    echo "------------------------------------------------------------"
    log "CRITICAL ERROR: Storage path NOT found!"
    log "Path: $STORAGE_PATH"
    log "Aborting start to prevent data loss."
    echo "------------------------------------------------------------"
    exit 1
fi

# 3. SECRET & ID MANAGEMENT
# Wir erstellen Hilfsdateien im /data Ordner, damit die Werte Neustarts überleben.

# --- A) JWT SECRET ---
JWT_SECRET_FILE="/data/oc_jwt_secret"
if [ ! -f "$JWT_SECRET_FILE" ]; then
    log "--> Generating new JWT secret..."
    tr -dc A-Za-z0-9 </dev/urandom | head -c 32 > "$JWT_SECRET_FILE"
fi
export OC_JWT_SECRET=$(cat "$JWT_SECRET_FILE")

# --- B) TRANSFER SECRET ---
TRANSFER_SECRET_FILE="/data/oc_transfer_secret"
if [ ! -f "$TRANSFER_SECRET_FILE" ]; then
    log "--> Generating new Transfer secret..."
    tr -dc A-Za-z0-9 </dev/urandom | head -c 32 > "$TRANSFER_SECRET_FILE"
fi
export OC_TRANSFER_SECRET=$(cat "$TRANSFER_SECRET_FILE")

# --- C) MACHINE AUTH SECRET ---
MACHINE_AUTH_FILE="/data/oc_machine_auth_secret"
if [ ! -f "$MACHINE_AUTH_FILE" ]; then
    log "--> Generating new Machine Auth secret..."
    tr -dc A-Za-z0-9 </dev/urandom | head -c 32 > "$MACHINE_AUTH_FILE"
fi
export OC_MACHINE_AUTH_API_KEY=$(cat "$MACHINE_AUTH_FILE")

# --- D) SYSTEM USER ID ---
SYSTEM_USER_ID_FILE="/data/oc_system_user_id"
if [ ! -f "$SYSTEM_USER_ID_FILE" ]; then
    log "--> Generating new System User UUID..."
    cat /proc/sys/kernel/random/uuid > "$SYSTEM_USER_ID_FILE"
fi
export OC_SYSTEM_USER_ID=$(cat "$SYSTEM_USER_ID_FILE")

# --- E) STORAGE MOUNT IDs (Neu) ---
# Damit Gateway und Storage Service wissen, wo die Daten liegen.

# 1. Users Mount ID (Fix für aktuellen Fehler)
USERS_MOUNT_ID_FILE="/data/oc_storage_users_mount_id"
if [ ! -f "$USERS_MOUNT_ID_FILE" ]; then
    log "--> Generating new Storage Users Mount ID..."
    cat /proc/sys/kernel/random/uuid > "$USERS_MOUNT_ID_FILE"
fi
export OC_STORAGE_USERS_MOUNT_ID=$(cat "$USERS_MOUNT_ID_FILE")

# 2. System Mount ID (Prophylaktisch)
SYSTEM_MOUNT_ID_FILE="/data/oc_storage_system_mount_id"
if [ ! -f "$SYSTEM_MOUNT_ID_FILE" ]; then
    log "--> Generating new Storage System Mount ID..."
    cat /proc/sys/kernel/random/uuid > "$SYSTEM_MOUNT_ID_FILE"
fi
export OC_STORAGE_SYSTEM_MOUNT_ID=$(cat "$SYSTEM_MOUNT_ID_FILE")


# 4. Environment Variablen setzen
export OC_SERVER_ROOT="/data"
export OC_SERVER_ADDRESS="0.0.0.0"
export OC_SERVER_PORT="9200"
export OC_URL="https://$DOMAIN"
export OC_INSECURE="true"
export OC_STORAGE_LOCAL_ROOT="$STORAGE_PATH"
export OC_BASE_DATA_PATH="/data"
export OC_CONFIG_FILE="/data/opencloud.yaml"

log "--> Checking/Initializing OpenCloud configuration..."

# Init, falls noch keine Config existiert
if [ ! -f "/data/opencloud.yaml" ]; then
    log "--> No config found. Initializing..."
    opencloud init || true
else
    log "--> Config found. Skipping initialization."
fi

log "--> Starting OpenCloud Server..."
echo "------------------------------------------------"

# Starten
exec opencloud server
