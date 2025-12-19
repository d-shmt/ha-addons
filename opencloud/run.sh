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
# Config Ordner auf HA-Disk anlegen
mkdir -p /data/config
# Data Ordner auf NAS anlegen (falls leer)
mkdir -p "$STORAGE_PATH"

# 4. SYMLINK MAGIE (Das Herzstück)
# Wir löschen die Standard-Ordner im Container und ersetzen sie durch Links zu deinen Pfaden.

# A) CONFIG: /etc/opencloud -> /data/config
if [ -d "/etc/opencloud" ] && [ ! -L "/etc/opencloud" ]; then
    rm -rf /etc/opencloud
fi
# Erstelle Link nur, wenn er noch nicht existiert
if [ ! -L "/etc/opencloud" ]; then
    log "--> Linking internal config path to /data/config..."
    ln -s /data/config /etc/opencloud
fi

# B) DATA: /var/lib/opencloud -> NAS Share
if [ -d "/var/lib/opencloud" ] && [ ! -L "/var/lib/opencloud" ]; then
    rm -rf /var/lib/opencloud
fi
# Erstelle Link nur, wenn er noch nicht existiert
if [ ! -L "/var/lib/opencloud" ]; then
    log "--> Linking internal data path to NAS Share..."
    ln -s "$STORAGE_PATH" /var/lib/opencloud
fi

# 5. ENVIRONMENT VARIABLEN
# Wir setzen nur noch die nötigsten Netzwerksachen. Pfade sind durch Symlinks geregelt.
export OC_SERVER_ADDRESS="0.0.0.0"
export OC_SERVER_PORT="9200"
export OC_URL="https://$DOMAIN"
export OC_INSECURE="true"

# Wir setzen explizit KEINE Pfad-Variablen mehr, da die Symlinks das regeln!
# Das verhindert Konflikte.

# 6. INITIALISIERUNG
if [ -f "/data/config/opencloud.yaml" ]; then
    log "--> Config found. Skipping init."
else
    log "--> No config found. Initializing..."
    # Init schreibt nun automatisch nach /etc/opencloud -> landet in /data/config
    opencloud init || true
fi

# 7. CONFIG PATCHING (Mount IDs Fix)
# Wir müssen sicherstellen, dass die IDs in der Config stehen.
# Da die Datei jetzt sicher in /data/config/opencloud.yaml liegt, können wir sie bearbeiten.
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
exec opencloud server
