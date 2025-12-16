#!/bin/sh
set -e

echo "--> Starte OpenCloud Add-on Wrapper..."

# 1. Konfiguration auslesen
CONFIG_PATH=/data/options.json
ADMIN_PASS=$(jq --raw-output '.admin_password' $CONFIG_PATH)
OC_URL_VAL=$(jq --raw-output '.oc_url' $CONFIG_PATH)

# 2. Persistenz sicherstellen (Daten müssen in /data liegen!)
echo "--> Bereite Dateisystem vor..."

# Ordner im persistenten HA-Speicher erstellen
mkdir -p /data/config
mkdir -p /data/data

# Rechte an den 'opencloud' User (ID 1000) übergeben
chown -R 1000:1000 /data/config
chown -R 1000:1000 /data/data

# Symlinks erstellen: Wenn OpenCloud auf /etc/opencloud zugreift,
# landet es eigentlich in /data/config
# (Alte Ordner löschen, falls sie existieren, damit der Link klappt)
rm -rf /etc/opencloud && ln -s /data/config /etc/opencloud
rm -rf /var/lib/opencloud && ln -s /data/data /var/lib/opencloud

echo "--> Setze Umgebungsvariablen..."

# OpenCloud Umgebungsvariablen
export OC_INSECURE=true
export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
export OC_URL="$OC_URL_VAL"
export PROXY_HTTP_ADDR="0.0.0.0:9200"
# Pfade explizit setzen (zur Sicherheit, falls Symlinks nicht reichen)
export OC_CONFIG_DIR="/data/config"
export OC_BASE_DATA_PATH="/data/data"

echo "--> Initialisiere OpenCloud (falls nötig)..."
# Führe init als User 'opencloud' (ID 1000) aus
# "|| true" verhindert Abbruch, falls es schon initialisiert ist
su-exec 1000:1000 opencloud init || true

echo "--> Starte OpenCloud Server..."
# Starte den Server als User 'opencloud'
exec su-exec 1000:1000 opencloud server