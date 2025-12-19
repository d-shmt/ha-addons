ARG BUILD_FROM
# Use the official rolling image from Docker Hub
FROM opencloudeu/opencloud-rolling:latest

# Switch to root for installations
USER root

# Install jq (to parse config) and su-exec (to switch users)
# We assume the base image is based on Alpine Linux (common for Go apps)
RUN apk add --no-cache jq su-exec

# Copy the startup script
COPY run.sh /run.sh
RUN chmod a+x /run.sh

# IMPORTANT: We remain root for now; user switching happens in run.sh
ENTRYPOINT [ "/run.sh" ]
