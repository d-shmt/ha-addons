ARG BUILD_FROM
FROM opencloudeu/opencloud-rolling:latest

USER root

# jq und su-exec für Skript-Logik, curl für Healthchecks
RUN apk add --no-cache jq su-exec curl

COPY run.sh /run.sh
RUN chmod a+x /run.sh

ENTRYPOINT [ "/run.sh" ]
