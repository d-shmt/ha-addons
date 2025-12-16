ARG BUILD_FROM
FROM $BUILD_FROM

# 1. Standard-Tools installieren
RUN apk add --no-cache \
    jq \
    curl \
    libcap

# 2. Den User 'opencloud' (ID 1000) sauber anlegen
RUN addgroup -g 1000 opencloud \
    && adduser -u 1000 -G opencloud -s /bin/sh -D opencloud

# 3. OpenCloud Version definieren
ENV OCIS_VERSION=5.0.0

# 4. Skript kopieren
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# 5. Herunterladen (mit automatischer Architektur-Erkennung)
RUN ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then OCIS_ARCH="amd64"; \
       elif [ "$ARCH" = "aarch64" ]; then OCIS_ARCH="arm64"; \
       else echo "Unsupported architecture: $ARCH" && exit 1; fi \
    && echo "Downloading OpenCloud for $OCIS_ARCH..." \
    && curl -L -o /usr/bin/opencloud https://github.com/owncloud/ocis/releases/download/v${OCIS_VERSION}/ocis-${OCIS_VERSION}-linux-${OCIS_ARCH} \
    && chmod +x /usr/bin/opencloud

WORKDIR /data
CMD [ "/run.sh" ]
