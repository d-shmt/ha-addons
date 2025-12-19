#!/bin/sh

# 1. Konfiguration auslesen
ADMIN_PASS=$(grep -o '"admin_password": "[^"]*' /data/options.json | sed 's/"admin_password": "//')
DATA_PATH=$(grep -o '"data_path": "[^"]*' /data/options.json | sed 's/"data_path": "//')
# NEU: Domain/IP auslesen
SERVER_DOMAIN=$(grep -o '"server_domain": "[^"]*' /data/options.json | sed 's/"server_domain": "//')

# Fallbacks
if [ -z "$DATA_PATH" ]; then DATA_PATH="/data/opencloud"; fi
# Wenn keine Domain angegeben ist, versuchen wir localhost (wird aber fehlschlagen von extern)
if [ -z "$SERVER_DOMAIN" ]; then SERVER_DOMAIN="localhost"; fi

echo "Setup für Domain: $SERVER_DOMAIN"
echo "Verwende Speicherpfad: $DATA_PATH"

# 2. Verzeichnisse vorbereiten (NAS Logic)
if [ ! -d "$DATA_PATH" ]; then
    echo "Erstelle Verzeichnis $DATA_PATH..."
    mkdir -p "$DATA_PATH"
fi

mkdir -p "$DATA_PATH/config"
mkdir -p "$DATA_PATH/data"

rm -rf /etc/opencloud
rm -rf /var/lib/opencloud

ln -s "$DATA_PATH/config" /etc/opencloud
ln -s "$DATA_PATH/data" /var/lib/opencloud

# 3. Umgebungsvariablen für OpenCloud setzen
if [ -z "$ADMIN_PASS" ]; then
    export IDM_ADMIN_PASSWORD="admin"
else
    export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
fi

# WICHTIG: Die URL setzen!
# Wir erzwingen HTTPS, da OpenCloud das standardmäßig so will.
export OC_URL="https://$SERVER_DOMAIN:9200"

# Erlaubt selbst-signierte Zertifikate (wichtig für interne IPs)
export OC_INSECURE=true

# Weitere Variablen, die helfen können CORS-Fehler zu vermeiden
export OCIS_URL="https://$SERVER_DOMAIN:9200"
export PROXY_HTTP_ADDR="0.0.0.0:9200"

# 4. Starten
echo "Starte OpenCloud Init..."
opencloud init --insecure true || true

echo "Starte OpenCloud Server..."
exec opencloud server
