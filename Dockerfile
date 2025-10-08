FROM jrei/systemd-ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create proper directory structure
RUN mkdir -p /etc/greengrass/config.d
