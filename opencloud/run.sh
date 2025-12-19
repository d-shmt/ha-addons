#!/usr/bin/with-contenv bashio

set -e

# Read configuration from Home Assistant
DOMAIN=$(bashio::config 'domain')
DATA_PATH=$(bashio::config 'data_path')
CONFIG_PATH=$(bashio::config 'config_path')
ADMIN_PASSWORD=$(bashio::config 'admin_password')
LOG_LEVEL=$(bashio::config 'log_level')

# Log configuration
bashio::log.info "Starting OpenCloud..."
bashio::log.info "Domain: ${DOMAIN}"
bashio::log.info "Data path: ${DATA_PATH}"
bashio::log.info "Config path: ${CONFIG_PATH}"

# Validate configuration
if bashio::var.is_empty "${ADMIN_PASSWORD}"; then
    bashio::exit.nok "Admin password is required!"
fi

# Create directories if they don't exist
mkdir -p "${DATA_PATH}"
mkdir -p "${CONFIG_PATH}"

# Check if NFS paths are accessible
if [ ! -d "${DATA_PATH}" ]; then
    bashio::exit.nok "Data path ${DATA_PATH} is not accessible. Please check your NFS mount."
fi

if [ ! -d "${CONFIG_PATH}" ]; then
    bashio::exit.nok "Config path ${CONFIG_PATH} is not accessible. Please check your NFS mount."
fi

# Set environment variables for OpenCloud
export OC_INSECURE=false
export PROXY_HTTP_ADDR=0.0.0.0:9200
export OC_URL=https://${DOMAIN}
export OC_LOG_LEVEL=${LOG_LEVEL}
export IDM_ADMIN_PASSWORD=${ADMIN_PASSWORD}
export IDM_CREATE_DEMO_USERS=false

# Change to config directory
cd "${CONFIG_PATH}"

bashio::log.info "Initializing OpenCloud (if needed)..."

# Run OpenCloud init and then start server
# The init will only run if config doesn't exist yet
exec /bin/sh -c "opencloud init || true; opencloud server"
