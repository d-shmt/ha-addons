#!/bin/sh
set -e

echo "--> Starting OpenCloud Add-on (Release v1.0)..."

# --- CONFIGURATION ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- STORAGE SETUP ---
# We keep metadata locally (fast SSD) and blobs on NAS (large storage)
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

mkdir -p $OC_BASE_DATA_PATH $OC_CONFIG_DIR

# Check if NAS path is actually mounted
NAS_BLOBS="$NAS_PATH_VAL/blobs"
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "CRITICAL ERROR: The data path ($NAS_PATH_VAL) was not found!"
    echo "Please check if your NAS is correctly mounted in Home Assistant."
    # We continue, but the server will likely fail later if it tries to write
fi

# Create blobs directory on NAS if missing
if [ ! -d "$NAS_BLOBS" ]; then
    echo "--> Creating blobs directory on NAS..."
    mkdir -p "$NAS_BLOBS"
fi

# Try to set permissions (might fail on some NFS shares, which is fine)
chown -R 1000:1000 "$NAS_BLOBS" || echo "WARNING: Could not set permissions on NAS (Root Squash?)"

# --- ENVIRONMENT VARIABLES ---
# Logging Level (info is standard, debug is verbose)
export OC_LOG_LEVEL="info"

# Proxy & Security Settings
# We disable internal TLS to allow proper Proxy Termination (Traefik/Nginx)
export OC_INSECURE=true
export PROXY_TLS=false
export PROXY_HTTP_ADDR="0.0.0.0:9200"
# Trust all internal proxies (essential for Pangolin/Traefik Docker networks)
export PROXY_TRUSTED_PROXIES="0.0.0.0/0"

# Identity & URLs
# Ensuring consistency here prevents 500 Errors and Redirect Loops
export OC_URL="$OC_URL_VAL"
export OCIS_URL="$OC_URL_VAL"
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"

# --- CONFIG RESET & INIT ---
# We remove the config on every start to ensure HA options are always applied.
echo "--> Refreshing OpenCloud configuration..."
rm -f /data/config/opencloud.yaml

echo "--> Initializing OpenCloud..."
# Ensure permissions are correct before init
chown -R 1000:1000 /data/data /data/config
su-exec 1000:1000 opencloud init > /dev/null 2>&1 || true

# --- HYBRID STORAGE SYMLINK ---
echo "--> Setting up Hybrid Storage (Symlinks)..."
LOCAL_STORAGE_USERS="/data/data/storage/users"
LOCAL_BLOBS="$LOCAL_STORAGE_USERS/blobs"

# Create parent directory structure
mkdir -p "$LOCAL_STORAGE_USERS"

# If 'blobs' exists locally as a real directory (and is empty), remove it
if [ -d "$LOCAL_BLOBS" ] && [ ! -L "$LOCAL_BLOBS" ]; then
    rmdir "$LOCAL_BLOBS" || true
fi

# Create the Symlink: Local 'blobs' points to NAS 'blobs'
if [ ! -L "$LOCAL_BLOBS" ]; then
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS"
    echo "--> Symlink created: Local -> NAS"
fi

# --- FINAL PERMISSIONS FIX ---
echo "--> Fixing file permissions..."
# -h ensures we change the link owner, not necessarily the target
chown -hR 1000:1000 /data/data /data/config

# --- START SERVER ---
echo "--> Starting OpenCloud Server..."
exec su-exec 1000:1000 opencloud server
