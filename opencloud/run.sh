#!/bin/sh
set -e

echo "--> Starting OpenCloud Add-on (Release v1.0.1)..."

# --- CONFIGURATION ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- STORAGE SETUP ---
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

mkdir -p $OC_BASE_DATA_PATH $OC_CONFIG_DIR

# NAS Check
NAS_BLOBS="$NAS_PATH_VAL/blobs"
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "CRITICAL ERROR: The data path ($NAS_PATH_VAL) was not found!"
    # We continue, but expect errors
fi

if [ ! -d "$NAS_BLOBS" ]; then
    echo "--> Creating blobs directory on NAS..."
    mkdir -p "$NAS_BLOBS"
fi

# Try to set permissions
chown -R 1000:1000 "$NAS_BLOBS" || echo "WARNING: Could not set permissions on NAS (Root Squash?)"

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
echo "--> Refreshing OpenCloud configuration..."
rm -f /data/config/opencloud.yaml

echo "--> Initializing OpenCloud..."
chown -R 1000:1000 /data/data /data/config

# HIER GEÄNDERT: s6-setuidgid statt su-exec
s6-setuidgid 1000 opencloud init > /dev/null 2>&1 || true

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
    echo "--> Symlink created: Local -> NAS"
fi

# --- FINAL PERMISSIONS FIX ---
echo "--> Fixing file permissions..."
chown -hR 1000:1000 /data/data /data/config

# --- START SERVER ---
echo "--> Starting OpenCloud Server..."
# HIER GEÄNDERT: s6-setuidgid statt su-exec
exec s6-setuidgid 1000 opencloud server
