ARG BUILD_FROM=ghcr.io/home-assistant/amd64-base:latest
FROM ${BUILD_FROM}

RUN apk add --no-cache bash ca-certificates

ENV OC_DATA_DIR=/data
ENV OC_CONFIG_DIR=/config

COPY run.sh /run.sh
RUN chmod +x /run.sh

CMD ["/run.sh"]
