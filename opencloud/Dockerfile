ARG BUILD_FROM
FROM $BUILD_FROM

# Install dependencies
# jq: JSON parsing
# curl: Downloading binary
# libcap: Network capabilities
# HINWEIS: su-exec entfernt!
RUN apk add --no-cache \
    jq \
    curl \
    libcap

# Create the user 'opencloud' with ID 1000
RUN addgroup -g 1000 opencloud \
    && adduser -u 1000 -G opencloud -s /bin/sh -D opencloud

# OpenCloud Version
ENV OCIS_VERSION=5.0.0

# Copy run script
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Architecture detection & Download
RUN ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then OCIS_ARCH="amd64"; \
       elif [ "$ARCH" = "aarch64" ]; then OCIS_ARCH="arm64"; \
       else echo "Unsupported architecture: $ARCH" && exit 1; fi \
    && echo "Downloading OpenCloud for $OCIS_ARCH..." \
    && curl -L -o /usr/bin/opencloud https://github.com/owncloud/ocis/releases/download/v${OCIS_VERSION}/ocis-${OCIS_VERSION}-linux-${OCIS_ARCH} \
    && chmod +x /usr/bin/opencloud

WORKDIR /data
CMD [ "/run.sh" ]
