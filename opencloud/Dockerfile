# Verwende das offizielle OpenCloud Rolling Image von Docker Hub
ARG BUILD_FROM=opencloudeu/opencloud-rolling:latest
FROM $BUILD_FROM

# Installiere bashio für Home Assistant Integration
RUN apk add --no-cache bash jq

# Kopiere das Start-Script
COPY run.sh /
RUN chmod a+x /run.sh

# Port freigeben
EXPOSE 9200

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:9200/ || exit 1

# Start script
CMD ["/run.sh"]
