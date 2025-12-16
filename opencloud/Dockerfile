ARG BUILD_FROM
FROM $BUILD_FROM

# Install dependencies
# jq: JSON parsing for options
# curl: Downloading the binary
# su-exec: Running as non-root user
# libcap: Network capabilities
RUN apk add --no-cache \
    jq \
    curl \
    su-exec \
    libcap

# OpenCloud Version
ENV OCIS_VERSION=5.0.0

# Copy run script
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# Download OpenCloud Binary based on architecture (AMD64 or ARM64)
RUN ARCH=$(uname -m) \
    && if [ "$ARCH" = "x86_64" ]; then OCIS_ARCH="amd64"; \
       elif [ "$ARCH" = "aarch64" ]; then OCIS_ARCH="arm64"; \
       else echo "Unsupported architecture: $ARCH" && exit 1; fi \
    && echo "Downloading OpenCloud for $OCIS_ARCH..." \
    && curl -L -o /usr/bin/opencloud https://github.com/owncloud/ocis/releases/download/v${OCIS_VERSION}/ocis-${OCIS_VERSION}-linux-${OCIS_ARCH} \
    && chmod +x /usr/bin/opencloud

# Set working directory
WORKDIR /data

CMD [ "/run.sh" ]
