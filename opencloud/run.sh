#!/usr/bin/with-contenv bashio

# HA Optionen auslesen
DOMAIN=$(bashio::config 'domain')
ADMIN_PASSWORD=$(bashio::config 'admin_password')

bashio::log.info "Starte OpenCloud für Domain: ${DOMAIN}"

# Verzeichnisse auf dem NFS-Share vorbereiten
export OCIS_BASE_DATA_PATH="/share/opencloud/data"
export OCIS_CONFIG_DIR="/share/opencloud/config"
mkdir -p $OCIS_BASE_DATA_PATH $OCIS_CONFIG_DIR

# Konfiguration für Reverse Proxy (Pangolin)
export OCIS_URL="https://${DOMAIN}"
export PROXY_TLS=false # Da Pangolin TLS übernimmt
export OCIS_INSECURE=true # Intern unverschlüsselt, Pangolin macht HTTPS

# Admin Passwort setzen (nur beim ersten Start relevant)
export IDM_ADMIN_PASSWORD=$ADMIN_PASSWORD

# OpenCloud starten (Hier nutzen wir das Binary aus dem Image)
# Hinweis: Je nach Image-Pfad anpassen
exec /usr/bin/ocis server
