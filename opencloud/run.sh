#!/bin/sh
set -e

echo "--> Starting OpenCloud Add-on (Hybrid Storage Mode)..."

# --- READ CONFIGURATION ---
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)
NAS_PATH_VAL=$(jq --raw-output '.data_path' $CONFIG_PATH)

# --- VALIDATION ---
if [ ! -d "$NAS_PATH_VAL" ]; then
    echo "ERROR: The path $NAS_PATH_VAL does not exist!"
    exit 1
fi

# --- PREPARE DIRECTORIES ---
export OC_BASE_DATA_PATH="/data/data"
export OC_CONFIG_DIR="/data/config"

# Local base directories
mkdir -p $OC_BASE_DATA_PATH
mkdir -p $OC_CONFIG_DIR

# NAS Blobs directory
NAS_BLOBS="$NAS_PATH_VAL/blobs"
if [ ! -d "$NAS_BLOBS" ]; then
    echo "--> Creating blobs directory on NAS..."
    mkdir -p "$NAS_BLOBS"
fi
# Try setting NAS permissions (ignore errors)
chown -R 1000:1000 "$NAS_BLOBS" || true

# --- VARIABLES ---
echo "--> Setting environment variables..."

# 1. SSL Termination: Speak only unencrypted HTTP internally
export OC_INSECURE=true
export PROXY_TLS=false

# 2. Main OCIS settings
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"
export PROXY_HTTP_ADDR="0.0.0.0:9200"

# 3. TRUST SETTINGS (Important for Pangolin!)
# We trust ALL private networks. This prevents the 400 error
# when Pangolin sends headers like "X-Forwarded-For".
export PROXY_TRUSTED_PROXIES="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,127.0.0.1"

# 4. Hybrid Storage paths
export OC_CONFIG_DIR="/data/config"
export OC_BASE_DATA_PATH="/data/data"

echo "--> Initializing OpenCloud config..."
# Create config if it doesn't exist yet
# We run chown beforehand so init is allowed to write
chown -R 1000:1000 /data/data /data/config
su-exec 1000:1000 opencloud init || true

# --- SYMLINK LOGIC ---
echo "--> Linking local storage to NAS..."
LOCAL_STORAGE_USERS="/data/data/storage/users"
LOCAL_BLOBS="$LOCAL_STORAGE_USERS/blobs"

# Create parent structure
mkdir -p "$LOCAL_STORAGE_USERS"

# Remove empty blobs folder if it exists and is not a link
if [ -d "$LOCAL_BLOBS" ] && [ ! -L "$LOCAL_BLOBS" ]; then
    rmdir "$LOCAL_BLOBS" || true
fi

# Set symlink
if [ ! -L "$LOCAL_BLOBS" ]; then
    ln -s "$NAS_BLOBS" "$LOCAL_BLOBS"
    echo "--> Symlink created."
fi

# --- FINAL PERMISSIONS FIX (IMPORTANT!) ---
echo "--> Fixing file permissions..."
# Force EVERYTHING in /data/data to user 1000.
# This fixes the "permission denied" error when creating 'metadata'.
# Important: -h ensures we change the symlink itself, not the target (NAS)
chown -hR 1000:1000 /data/data
chown -R 1000:1000 /data/config

echo "--> Starting OpenCloud Server..."
exec su-exec 1000:1000 opencloud server
