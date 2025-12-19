#!/bin/sh

# 1. Konfiguration auslesen
# Wir lesen das Passwort und den gewünschten Datenpfad aus
ADMIN_PASS=$(grep -o '"admin_password": "[^"]*' /data/options.json | sed 's/"admin_password": "//')
DATA_PATH=$(grep -o '"data_path": "[^"]*' /data/options.json | sed 's/"data_path": "//')

# Fallback, falls leer
if [ -z "$DATA_PATH" ]; then
    DATA_PATH="/data/opencloud"
fi

echo "Verwende Speicherpfad: $DATA_PATH"

# 2. Verzeichnisse vorbereiten
# Erstelle das Zielverzeichnis (egal ob lokal oder auf dem NAS)
if [ ! -d "$DATA_PATH" ]; then
    echo "Erstelle Verzeichnis $DATA_PATH..."
    mkdir -p "$DATA_PATH"
fi

# Erstelle Unterordner für Config und Data im Zielverzeichnis
mkdir -p "$DATA_PATH/config"
mkdir -p "$DATA_PATH/data"

# Aufräumen der Container-internen Pfade, um Symlinks zu ermöglichen
rm -rf /etc/opencloud
rm -rf /var/lib/opencloud

# 3. Symlinks setzen
# Wir verlinken die internen OpenCloud Pfade auf deinen gewählten Speicherort
ln -s "$DATA_PATH/config" /etc/opencloud
ln -s "$DATA_PATH/data" /var/lib/opencloud

# 4. Passwort Logik
if [ -z "$ADMIN_PASS" ]; then
    echo "Warnung: Kein Admin-Passwort gefunden, nutze Standard."
    export IDM_ADMIN_PASSWORD="admin"
else
    export IDM_ADMIN_PASSWORD="$ADMIN_PASS"
fi

# 5. Starten
export OC_INSECURE=true

echo "Starte OpenCloud Init..."
opencloud init --insecure true || true

echo "Starte OpenCloud Server..."
exec opencloud server
