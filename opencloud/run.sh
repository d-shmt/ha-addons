#!/bin/sh
set -e

echo "--> Starte OpenCloud (Direct NFS Mode)..."

# --- CONFIG ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
# Das ist jetzt der String: "192.168.x.x:/Pfad/..."
NFS_TARGET=$(jq --raw-output '.nfs_path' $CONFIG_PATH)

# --- PFADE ---
export OC_CONFIG_DIR="/data/config"
export OC_BASE_DATA_PATH="/data/data"

# Zielordner im Container (wo die Blobs hinsollen)
LOCAL_STORAGE_USERS="$OC_BASE_DATA_PATH/storage/users"
MOUNT_POINT="$LOCAL_STORAGE_USERS/blobs"

# --- STRUKTUR ---
mkdir -p "$OC_CONFIG_DIR"
mkdir -p "$LOCAL_STORAGE_USERS"

# Wichtig: Für einen Mount muss der Zielordner existieren (und leer sein)
if [ ! -d "$MOUNT_POINT" ]; then
    mkdir -p "$MOUNT_POINT"
fi

# --- MOUNT LOGIK ---
echo "--> Versuche direkten NFS Mount..."
echo "--> Quelle: $NFS_TARGET"
echo "--> Ziel:   $MOUNT_POINT"

# Mounten mit 'nolock' (wichtig für Container) und 'vers=4' (falls Proxmox v4 kann, sonst weglassen)
# Wir fangen Fehler ab, falls es schon gemountet ist
mount -t nfs -o rw,nolock,async "$NFS_TARGET" "$MOUNT_POINT" || echo "WARNUNG: Mount fehlgeschlagen oder bereits aktiv."

# Check ob Mount wirklich da ist
if mount | grep -q "$MOUNT_POINT"; then
    echo "--> ERFOLG: NFS Share ist gemountet!"
else
    echo "FEHLER: Konnte NFS Share nicht mounten. Bitte Log prüfen."
    # Wir machen hier keinen exit 1, sondern versuchen es trotzdem - vielleicht klappt der Start
fi

# --- RECHTE FIXEN ---
# Jetzt, wo das NAS eingehängt ist, gehören die Ordner evtl. root.
# Wir versuchen, sie für opencloud (1000) lesbar zu machen.
# Das klappt nur, wenn Proxmox (wie vorhin besprochen) 'all_squash' oder 'chmod 777' hat.
echo "--> Passe Rechte auf dem Mount an..."
chown -R 1000:1000 "$MOUNT_POINT" || echo "Info: Konnte Rechte auf Mount nicht ändern (bei NFS oft normal)."

# Lokale Config Rechte
chown -R 1000:1000 /data/data /data/config

# --- ENV & START ---
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
