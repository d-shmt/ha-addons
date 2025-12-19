#!/bin/bash
set -e

# Funktion für Log-Ausgaben
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

log "--> Starting OpenCloud Add-on Setup..."

# 1. Konfiguration auslesen
DOMAIN=$(jq --raw-output '.domain' $CONFIG_PATH)
STORAGE_PATH=$(jq --raw-output '.storage_path' $CONFIG_PATH)

log "--> Configuration loaded:"
log "    Domain: $DOMAIN"
log "    NAS Data Path: $STORAGE_PATH"
log "    Local Config Path: /data/config"

# 2. SICHERHEITS-CHECK: NAS Mount
if [ ! -d "$STORAGE_PATH" ]; then
    log "CRITICAL ERROR: Storage path $STORAGE_PATH NOT found!"
    log "Please ensure the NAS is mounted in Home Assistant."
    exit 1
fi

# 3. VERZEICHNISSTRUKTUR VORBEREITEN
# Config Ordner auf HA-Disk anlegen (Persistent)
mkdir -p /data/config
# Data Ordner auf NAS anlegen (falls noch nicht da)
mkdir -p "$STORAGE_PATH"

# 4. ENVIRONMENT VARIABLEN
export OC_SERVER_ADDRESS="0.0.0.0"
export OC_SERVER_PORT="9200"
export OC_URL="https://$DOMAIN"
export OC_INSECURE="true"

# WICHTIG: Wir sagen OpenCloud, wo die Basis-Daten liegen sollen (NAS)
# Damit umgehen wir das Löschen von /var/lib/opencloud
export OC_BASE_DATA_PATH="$STORAGE_PATH"

# Wir definieren, wo die Config liegen soll (für init)
export OC_CONFIG_FILE="/data/config/opencloud.yaml"

# 5. INITIALISIERUNG
if [ -f "/data/config/opencloud.yaml" ]; then
    log "--> Config found in /data/config. Skipping init."
else
    log "--> No config found. Initializing..."
    # Init schreibt nach /data/config/opencloud.yaml
    opencloud init || true
fi

# 6. SYMLINK FIX (Das löst den "Resource busy" Fehler)
# Wir löschen den Ordner NICHT. Wir verlinken nur die Config-Datei hinein.
log "--> Linking config file to /etc/opencloud/opencloud.yaml..."

# Sicherstellen, dass der Zielordner existiert (sollte er aber, da er busy war)
mkdir -p /etc/opencloud

# Symlink erzwingen (-f force), überschreibt existierende Datei im Container
ln -sf /data/config/opencloud.yaml /etc/opencloud/opencloud.yaml


# 7. CONFIG PATCHING (Mount IDs Fix)
# Wir patchen die Datei in /data/config, der Link in /etc übernimmt das automatisch.
CONFIG_FILE="/data/config/opencloud.yaml"

if ! grep -q "storage_users_mount_id:" "$CONFIG_FILE"; then
    log "--> Patching config: Appending missing Mount IDs..."
    
    MOUNT_ID_USERS="a0000000-0000-0000-0000-000000000001"
    MOUNT_ID_SYSTEM="a0000000-0000-0000-0000-000000000002"

    cat >> "$CONFIG_FILE" <<EOF

# --- Added by Home Assistant Add-on ---
storage_users_mount_id: "$MOUNT_ID_USERS"
storage_system_mount_id: "$MOUNT_ID_SYSTEM"

gateway:
  storage_users_mount_id: "$MOUNT_ID_USERS"
  storage_system_mount_id: "$MOUNT_ID_SYSTEM"

frontend:
  storage_users_mount_id: "$MOUNT_ID_USERS"

webdav:
  storage_users_mount_id: "$MOUNT_ID_USERS"

storage_users:
  mount_id: "$MOUNT_ID_USERS"

storage_system:
  mount_id: "$MOUNT_ID_SYSTEM"
# --------------------------------------
EOF
    log "--> Config patched successfully."
else
    log "--> Config already contains Mount IDs."
fi

log "--> Starting OpenCloud Server..."
echo "------------------------------------------------"

# Starten
# Da die Datei jetzt in /etc/opencloud/opencloud.yaml verlinkt ist,
# findet der Server sie automatisch.
exec opencloud server
