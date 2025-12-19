#!/bin/sh

# 1. Konfiguration auslesen
ADMIN_PASS=$(grep -o '"admin_password": "[^"]*' /data/options.json | sed 's/"admin_password": "//')
DATA_PATH=$(grep -o '"data_path": "[^"]*' /data/options.json | sed 's/"data_path": "//')
SERVER_DOMAIN=$(grep -o '"server_domain": "[^"]*' /data/options.json | sed 's/"server_domain": "//')

# Fallbacks
if [ -z "$DATA_PATH" ]; then DATA_PATH="/data/opencloud"; fi
if [ -z "$SERVER_DOMAIN" ]; then SERVER_DOMAIN="localhost"; fi

# 2. Verzeichnisse vorbereiten
if [ ! -d "$DATA_PATH" ]; then mkdir -p "$DATA_PATH"; fi
mkdir -p "$DATA_PATH/config"
mkdir -p "$DATA_PATH/data"

# Alte Symlinks löschen und neu setzen
rm -rf /etc/opencloud
rm -rf /var/lib/opencloud
ln -s "$DATA_PATH/config" /etc/opencloud
ln -s "$DATA_PATH/data" /var/lib/opencloud

# 3. Umgebungsvariablen setzen
if [ -z "$ADMIN_PASS" ]; then
    export IDM_ADMIN_PASSWORD="admin"
else
    export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
fi

# -- WICHTIGE ÄNDERUNGEN --

# Die Adresse, unter der der Server erreichbar ist (muss https:// sein)
export OCIS_URL="https://$SERVER_DOMAIN:9200"

# Erlaubt unsichere Zertifikate (Self-Signed)
export OCIS_INSECURE=true

# Proxy Einstellungen, damit OCIS auf alle IPs hört
export PROXY_HTTP_ADDR="0.0.0.0:9200"
# Deaktiviert TLS innerhalb des Containers (optional, falls SSL Probleme macht,
# aber OCIS macht SSL oft selbst. Lassen wir es erstmal an, da wir HTTPS im Link haben)

# Erzwingt, dass Env-Variablen Vorrang vor der Config-Datei haben
export OCIS_CONFIG_DIR="/etc/opencloud"

echo "Starte OCIS mit URL: $OCIS_URL"
echo "Speicherpfad: $DATA_PATH"

# 4. Starten
# Wir führen 'init' nicht mehr bei jedem Start aus, das kann Configs überschreiben.
# OCIS generiert Configs beim Start automatisch, wenn sie fehlen.

echo "Starte OpenCloud Server..."
exec opencloud server
