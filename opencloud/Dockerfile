# Wir nutzen das offizielle Image als Basis
FROM opencloudeu/opencloud:latest

# Root-User ist nötig, um Pakete zu installieren und Berechtigungen zu setzen
USER root

# Installation von Bash und jq
RUN apk add --no-cache bash jq coreutils

# Kopieren des Start-Skripts
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Environment Variablen für Home Assistant Pfade
ENV CONFIG_PATH=/data/options.json

# WICHTIG: Wir setzen den Entrypoint zurück!
# Damit verhindern wir, dass automatisch /opencloud gestartet wird.
ENTRYPOINT []

# Jetzt starten wir unser Skript als Hauptprozess
CMD [ "/run.sh" ]
