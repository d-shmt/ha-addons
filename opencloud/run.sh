#!/bin/sh
set -e

echo "--> Starte OpenCloud (Direct NFS Mode)..."

# --- CONFIG LESEN ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)

# WICHTIG: Wir nutzen einfach '.data_path'. 
# Das Feld hast du schon in der UI!
NFS_TARGET=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- VALIDIERUNG ---
if [ "$NFS_TARGET" = "null" ] || [ -z "$NFS_TARGET" ]; then
    echo "FEHLER: 'data_path' ist leer! Bitte trage den NFS-Pfad in die Konfiguration ein."
    echo "Format: 192.168.1.100:/HDD/opencloud-data/blobs"
    exit 1
fi

echo "--> NFS Target: $NFS_TARGET"

# --- PFADE ---
export OC_CONFIG_DIR="/data/config"
export OC_BASE_DATA_PATH="/data/data"

# Zielordner im Container
LOCAL_STORAGE_USERS="$OC_BASE_DATA_PATH/storage/users"
MOUNT_POINT="$LOCAL_STORAGE_USERS/blobs"

# --- STRUKTUR ---
mkdir -p "$OC_CONFIG_DIR"
mkdir -p "$LOCAL_STORAGE_USERS"

# Mountpoint erstellen
if [ ! -d "$MOUNT_POINT" ]; then
    mkdir -p "$MOUNT_POINT"
fi

# --- MOUNT LOGIK ---
# Check ob schon gemountet (bei Restart des Containers)
if mount | grep -q "$MOUNT_POINT"; then
    echo "Info: Share ist bereits gemountet."
else
    echo "--> Versuche Mount..."
    # Wir mounten mit 'nolock', das ist in Containern oft stabiler
    mount -t nfs -o rw,nolock,async "$NFS_TARGET" "$MOUNT_POINT"
fi

# Check ob es geklappt hat
if mount | grep -q "$MOUNT_POINT"; then
    echo "--> ERFOLG: NFS Share ist eingehängt!"
    # Rechte fixen (falls möglich)
    chown -R 1000:1000 "$MOUNT_POINT" || echo "Info: Rechte auf NFS konnten nicht geändert werden (Check Proxmox all_squash)"
else
    echo "FEHLER: Mount fehlgeschlagen!"
    exit 1
fi

# --- START ---
# Rechte lokal
chown -R 1000:1000 /data/data /data/config

export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"
export OC_CONFIG_DIR=$OC_CONFIG_DIR
export OC_BASE_DATA_PATH=$OC_BASE_DATA_PATH

echo "--> Initialisiere OpenCloud..."
su-exec 1000:1000 opencloud init || true

echo "--> Starte Server..."
exec su-exec 1000:1000 opencloud server
