ARG BUILD_FROM
FROM $BUILD_FROM

# Metadaten Labels für bessere Wartbarkeit
LABEL io.hass.version="rolling" \
      io.hass.type="addon" \
      io.hass.arch="aarch64|amd64"

# Umgebungsvariablen für den Build-Prozess
ENV LANG C.UTF-8

# Installation grundlegender Abhängigkeiten
# OpenCloud benötigt Zertifikate (ca-certificates) für externe Verbindungen (OIDC, App Store)
# mailcap wird für MIME-Type-Erkennung benötigt
# curl und jq für Healthchecks und Skripting
RUN apk add --no-cache \
    curl \
    ca-certificates \
    mailcap \
    jq \
    bash

# Kopieren des OpenCloud Binaries aus dem offiziellen Image
# Dieser Schritt isoliert uns von Build-Tools, die für Go nötig wären
COPY --from=opencloudeu/opencloud-rolling:latest /usr/bin/opencloud /usr/bin/opencloud

# Arbeitsverzeichnis definieren
WORKDIR /var/lib/opencloud

# Kopieren der lokalen Skripte (Startlogik)
COPY rootfs /

# Berechtigungen setzen
# S6 Overlay Skripte müssen ausführbar sein
RUN chmod a+x /etc/services.d/opencloud/run \
    && chmod a+x /etc/services.d/opencloud/finish

# Port Dokumentation (wird von HAOS gelesen, aber nicht zwingend exponiert ohne config)
EXPOSE 9200
