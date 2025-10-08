FROM jrei/systemd-ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download and install AWS Greengrass Lite properly
RUN cd /tmp && \
    wget -O greengrass-lite.zip https://github.com/aws-greengrass/aws-greengrass-lite/releases/download/v2.2.2/aws-greengrass-lite-ubuntu-x86-64.zip && \
    unzip greengrass-lite.zip -d greengrass && \
    cd greengrass && \
    apt-get update && \
    apt-get install -y ./aws-greengrass-lite-2.2.2-Linux.deb && \
    rm -rf /tmp/greengrass*

# Create proper directory structure
RUN mkdir -p /etc/greengrass/config.d

# Cleanup
RUN rm -rf /var/lib/apt/lists/*
