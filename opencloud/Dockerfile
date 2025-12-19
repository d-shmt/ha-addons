FROM opencloudeu/opencloud-rolling:latest

USER root

# WICHTIG: Das ursprüngliche Entrypoint überschreiben/löschen!
# Damit verhindern wir, dass 'opencloud' automatisch gestartet wird
# und unser Skript als Parameter interpretiert.
ENTRYPOINT []

COPY run.sh /run.sh
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]
