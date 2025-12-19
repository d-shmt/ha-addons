# Nutze das offizielle OpenCloud Image
FROM opencloud/ocis:latest

# Installiere Bash und Curl für das HA-Ökosystem
USER root
RUN apk add --no-cache bash curl jq

# Kopiere HA-spezifische Hilfsmittel (bashio)
# Wir simulieren hier die HA-Umgebung
COPY run.sh /
RUN chmod a+x /run.sh

# OpenCloud Standard-Ports
EXPOSE 9200

ENTRYPOINT [ "/bin/bash", "/run.sh" ]
