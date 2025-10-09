ARG BASE_IMAGE=debian:trixie-slim
FROM ${BASE_IMAGE}
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get -y install --no-install-recommends \
    systemd systemd-sysv dbus ca-certificates sudo nano bash-completion \
    build-essential pkg-config cmake git curl file gdb python3 \
    libssl-dev libcurl4-openssl-dev libsqlite3-dev sqlite3 libyaml-dev \
    libsystemd-dev liburiparser-dev uuid-dev libevent-dev cgroup-tools zlib1g-dev \
    libzstd-dev \
    unzip \
  && apt-get clean

# Build static libzip
RUN echo "deb-src http://deb.debian.org/debian trixie main" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get source libzip && \
    cd libzip-* && \
    cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=/usr -DENABLE_ZSTD=OFF . && \
    make -j$(nproc) && \
    make install

# Build and install AWS Greengrass Lite from source
RUN cd /tmp && \
    git clone https://github.com/aws-greengrass/aws-greengrass-lite.git && \
    cd aws-greengrass-lite && \
    mkdir build && cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf /tmp/aws-greengrass-lite

# Remove build dependencies and clean up
RUN apt-get remove -y --purge \
    build-essential pkg-config cmake git curl file gdb python3 \
    libssl-dev libcurl4-openssl-dev libsqlite3-dev libyaml-dev \
    libsystemd-dev liburiparser-dev uuid-dev libevent-dev zlib1g-dev \
    libzstd-dev \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /libzip-* \
    && rm -rf /tmp/* \
    && apt-get update \
    && apt-get install -y libyaml-0-2 liburiparser1 libcurl4t64 libsqlite3-0 libevent-2.1-7t64 libzstd1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create users and groups and run postinst steps
RUN groupadd -r ggcore && \
    useradd -r -g ggcore -s /bin/false ggcore && \
    groupadd -r gg_component && \
    useradd -r -g gg_component -s /bin/false gg_component && \
    mkdir -p /etc/greengrass/config.d /var/lib/greengrass && \
    chown ggcore:ggcore /var/lib/greengrass && \
    chmod 755 /etc/greengrass/config.d

# Create default config file
RUN cat > /etc/greengrass/config.d/greengrass-lite.yaml << 'EOF'
---
system:
  rootPath: "/var/lib/greengrass"
services:
  aws.greengrass.NucleusLite:
    componentType: "NUCLEUS"
    configuration:
      runWithDefault:
        posixUser: "ggcore:ggcore"
      greengrassDataPlanePort: "8443"
      platformOverride: {}
EOF

# Enable all systemd services and sockets
RUN systemctl enable greengrass-lite.target && \
    systemctl enable ggl.aws_iot_tes.socket && \
    systemctl enable ggl.aws_iot_mqtt.socket && \
    systemctl enable ggl.gg_config.socket && \
    systemctl enable ggl.gg_health.socket && \
    systemctl enable ggl.gg_fleet_status.socket && \
    systemctl enable ggl.gg_deployment.socket && \
    systemctl enable ggl.gg_pubsub.socket && \
    systemctl enable ggl.ipc_component.socket && \
    systemctl enable ggl.gg-ipc.socket.socket && \
    systemctl enable ggl.core.ggconfigd.service && \
    systemctl enable ggl.core.iotcored.service && \
    systemctl enable ggl.core.tesd.service && \
    systemctl enable ggl.core.ggdeploymentd.service && \
    systemctl enable ggl.core.gg-fleet-statusd.service && \
    systemctl enable ggl.core.ggpubsubd.service && \
    systemctl enable ggl.core.gghealthd.service && \
    systemctl enable ggl.core.ggipcd.service && \
    systemctl enable ggl.aws.greengrass.TokenExchangeService.service

# Create systemd service files
# greengrass-lite.target is already installed by the Greengrass build process

# Create setup service
RUN cat > /etc/systemd/system/greengrass-setup.service << 'EOF'
[Unit]
Description=Greengrass Connection Kit Setup and Start
After=multi-user.target
Wants=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'if [ -f /etc/greengrass/*.zip ]; then echo "Setting up Greengrass"; cd /etc/greengrass && unzip -o *.zip; sed -i -e "s:{{config_dir}}:/etc/greengrass:g" -e "s:{{nucleus_component}}:aws.greengrass.NucleusLite:g" config.yaml; chown ggcore:ggcore *.pem* config.yaml; chmod 644 device.pem.crt AmazonRootCA1.pem; chmod 600 private.pem.key; systemctl enable greengrass-lite.target; systemctl start greengrass-lite.target; echo "Greengrass setup complete"; else echo "No connection kit found"; fi'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

COPY ./getty-override.conf \
  /etc/systemd/system/console-getty.service.d/override.conf

RUN echo "export MAKEFLAGS=-j" >> /root/.profile

CMD ["/lib/systemd/systemd"]
