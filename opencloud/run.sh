#!/usr/bin/with-contenv bashio

# Laden der Konfigurationswerte
OC_DOMAIN=$(bashio::config 'oc_domain')
ADMIN_PASS=$(bashio::config 'initial_admin_password')
LOG_LEVEL=$(bashio::config 'log_level')
INSECURE=$(bashio::config 'oc_insecure')

# Konvertierung der Trusted Proxies Liste in Komma-separierten String
TRUSTED_PROXIES_LIST=$(bashio::config 'trusted_proxies')
# Hier müsste Logik folgen, um das JSON-Array von Bashio in einen String zu parsen
# Wir exportieren es als Variable für OpenCloud

# Export der OpenCloud-spezifischen Variablen 
export OC_URL="https://${OC_DOMAIN}"
export OC_LOG_LEVEL="${LOG_LEVEL}"
export OC_INSECURE="${INSECURE}"
export PROXY_HTTP_ADDR="0.0.0.0:9200" # Zwingend 0.0.0.0 für Docker Access [16]
export IDM_ADMIN_PASSWORD="${ADMIN_PASS}"

# Initialisierung bei erstem Start
CONFIG_DIR="/data/config"
export OC_CONFIG_DIR="${CONFIG_DIR}"

if; then
    bashio::log.info "Erste Einrichtung erkannt. Initialisiere OpenCloud..."
    # Init-Befehl erzeugt Zertifikate und Konfigurationsdateien
    # Wir nutzen su-exec oder setpriv um als User 1000 zu laufen
    opencloud init --insecure "${INSECURE}"
fi

bashio::log.info "Starte OpenCloud Server..."
exec opencloud server
