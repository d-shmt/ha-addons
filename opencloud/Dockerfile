# Wir nutzen das offizielle Image als Basis
FROM opencloudeu/opencloud:latest

# Root-User ist nötig, um Pakete zu installieren und Berechtigungen zu setzen
USER root

# Installation von Bash und jq (für das Parsing der config)
# Da das Base-Image auf Alpine basiert, nutzen wir apk
RUN apk add --no-cache bash jq coreutils

# Kopieren des Start-Skripts
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Environment Variablen für Home Assistant Pfade
ENV CONFIG_PATH=/data/options.json

# Startbefehl
CMD [ "/run.sh" ]
