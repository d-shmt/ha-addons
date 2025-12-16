#!/bin/sh
set -e

echo "--> Starting OpenCloud Add-on (Fixed Version)..."

# --- CONFIGURATION ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- STORAGE SETUP ---
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

mkdir -p $OC_BASE_DATA_PATH $OC_CONFIG_DIR

# NAS Setup
NAS_BLOBS="$NAS_PATH_VAL/blobs"
if [ ! -d "$NAS_BLOBS" ]; then
    echo "--> Creating blobs directory on NAS..."
    mkdir -p "$NAS_BLOBS"
fi

# Try setting permissions on NAS (ignore errors)
chown -R 1000:1000 "$NAS_BLOBS" || true

# --- ENVIRONMENT VARIABLES ---
export OC_LOG_LEVEL="info"
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
export PROXY_TRUSTED_PROXIES="0.0.0.0/0"
export OC_URL="$OC_URL_VAL"
export OCIS_URL="$OC_URL_VAL"
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"

# --- CONFIG RESET & INIT ---
echo "--> Refreshing Config..."
rm -f /data/config/opencloud.yaml

echo "--> Initializing OpenCloud..."
# WICHTIG: Rechte setzen
chown -R 1000:1000 /data/data /data/config

# WICHTIG: Der Fix! Wir nutzen 'su' statt s6-Tools
su -s /bin/sh opencloud -c "opencloud init" > /dev/null 2>&1 || true

# --- HYBRID STORAGE SYMLINK ---
echo "--> Setting up Hybrid Storage..."
LOCAL_STORAGE_USERS="/data/data/storage/users"
LOCAL_BLOBS="$LOCAL_STORAGE_USERS/blobs"
mkdir -p "$LOCAL_STORAGE_USERS"

if [ -d "$LOCAL_BLOBS" ] && [ ! -L "$LOCAL_BLOBS" ]; then
    rmdir "$LOCAL_BLOBS" || true
fi

if [ ! -L "$LOCAL_BLOBS" ]; then
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS"
    echo "--> Symlink created."
fi

# Final Permissions
chown -hR 1000:1000 /data/data /data/config

# --- START SERVER ---
echo "--> Starting Server..."
# WICHTIG: Der finale Start mit 'su'
exec su -s /bin/sh opencloud -c "opencloud server"
