ARG BUILD_FROM
# Wir nutzen das offizielle Rolling-Image von Docker Hub
FROM opencloudeu/opencloud-rolling:latest

# Wechsel zu Root für Installationen
USER root

# Installiere jq (Config lesen) und su-exec (User wechseln)
# Wir nehmen an, das Base-Image basiert auf Alpine Linux (üblich für Go Apps)
RUN apk add --no-cache jq su-exec

# Kopiere das Start-Skript
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# WICHTIG: Wir bleiben vorerst root, der User-Wechsel passiert im run.sh
ENTRYPOINT [ "/run.sh" ]