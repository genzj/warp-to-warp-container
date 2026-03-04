# Use the latest Ubuntu image as the base
FROM ubuntu:jammy

# Set environment variables to prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

ENV DBUS_SESSION_BUS_ADDRESS="unix:path=/var/run/dbus/system_bus_socket"

# Create a startup script
RUN printf '#!/bin/bash\nwhile true; do sleep 3600; done' > /start.sh && \
    chmod +x /start.sh

# Update the package list and install necessary tools
# hadolint ignore=DL3008,DL3009  # will clean list later
RUN apt-get update && apt-get install --no-install-recommends -y \
    curl \
    ca-certificates \
    gpg \
    lsb-release \
    dbus \
    iptables

# Add Cloudflare's GPG key to the keyring
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

# Add Cloudflare's repository to the sources list
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list

# Update package list and install Cloudflare WARP
# hadolint ignore=DL3008  # always use the latest version
RUN apt-get update && apt-get install --no-install-recommends -y cloudflare-warp \
    && rm -rf /var/lib/apt/lists/*

COPY settings.json /etc/default/cloudflare-warp-settings.json
COPY run.sh /run.sh

# Create a volume for the Cloudflare WARP data directory
VOLUME /var/lib/cloudflare-warp

# Set the default command to run the startup script
CMD ["/bin/bash", "/run.sh"]
