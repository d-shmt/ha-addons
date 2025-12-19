ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:3.18
FROM $BUILD_FROM

# Installiere Abhängigkeiten (falls nötig)
RUN apk add --no-cache curl

# Kopiere Start-Skript
COPY run.sh /
RUN chmod a+x /run.sh

# OpenCloud Umgebungsvariablen vorbereiten
ENV OCIS_INSECURE=false

CMD [ "/run.sh" ]
