FROM jrei/systemd-ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Download AWS Greengrass Lite
RUN wget -O /tmp/greengrass-lite.zip https://github.com/aws-greengrass/aws-greengrass-lite/releases/download/v2.2.2/aws-greengrass-lite-ubuntu-x86-64.zip \
    && unzip /tmp/greengrass-lite.zip -d /tmp/greengrass \
    && rm /tmp/greengrass-lite.zip

# Install Greengrass Lite package (ignore systemd configuration errors)
RUN cd /tmp/greengrass \
    && apt-get update \
    && dpkg -i aws-greengrass-lite*.deb; apt-get install -f -y; exit 0

# Cleanup
RUN rm -rf /tmp/greengrass /var/lib/apt/lists/*
