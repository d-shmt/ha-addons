ARG BUILD_FROM
FROM opencloudeu/opencloud-rolling:latest

USER root

# NEU: nfs-utils und rpcbind hinzufügen
RUN apk add --no-cache jq su-exec nfs-utils rpcbind

COPY run.sh /run.sh
RUN chmod a+x /run.sh

ENTRYPOINT [ "/run.sh" ]
