#!/bin/sh

# 1. Konfiguration auslesen
ADMIN_PASS=$(grep -o '"admin_password": "[^"]*' /data/options.json | sed 's/"admin_password": "//')
DATA_PATH=$(grep -o '"data_path": "[^"]*' /data/options.json | sed 's/"data_path": "//')
SERVER_DOMAIN=$(grep -o '"server_domain": "[^"]*' /data/options.json | sed 's/"server_domain": "//')

# Fallbacks & Bereinigung der Domain (entfernt führendes http:// oder https:// falls eingetragen)
SERVER_DOMAIN=$(echo "$SERVER_DOMAIN" | sed -e 's|^https://||' -e 's|^http://||')
if [ -z "$DATA_PATH" ]; then DATA_PATH="/data/opencloud"; fi
if [ -z "$SERVER_DOMAIN" ]; then SERVER_DOMAIN="localhost"; fi

# 2. Verzeichnisse auf dem NAS vorbereiten
echo "Speicherpfad: $DATA_PATH"
mkdir -p "$DATA_PATH/config"
mkdir -p "$DATA_PATH/data"

# 3. Resource Busy Fix: Inhalt löschen statt Ordner
# Wir leeren die internen Ordner und mounten den NAS-Pfad darüber
echo "Verknüpfe NAS-Speicher..."
mount --bind "$DATA_PATH/config" /etc/opencloud
mount --bind "$DATA_PATH/data" /var/lib/opencloud

# 4. Umgebungsvariablen setzen
export IDM_ADMIN_PASSWORD="${ADMIN_PASS:-admin}"
export OCIS_URL="https://$SERVER_DOMAIN:9200"
export OCIS_INSECURE=true
export PROXY_HTTP_ADDR="0.0.0.0:9200"

# WICHTIG: Erzeugt Secrets automatisch, falls sie in der config fehlen
export OCIS_ADD_RUN_SERVICES=true

echo "Starte OCIS mit URL: $OCIS_URL"

# 5. Initialisierung (nur wenn config leer ist)
if [ ! -f /etc/opencloud/ocis.yaml ]; then
    echo "Initialisiere neue Konfiguration..."
    opencloud init --insecure true || true
fi

echo "Starte OpenCloud Server..."
exec opencloud server
