ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get -y install --no-install-recommends \
    systemd systemd-sysv dbus ca-certificates sudo nano bash-completion \
    build-essential pkg-config cmake git curl file gdb python3 \
    libssl-dev libcurl4-openssl-dev libsqlite3-dev sqlite3 libyaml-dev \
    libsystemd-dev liburiparser-dev uuid-dev libevent-dev cgroup-tools zlib1g-dev \
    unzip \
  && apt-get clean

# Build static libzip
RUN echo "deb-src http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb-src http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    apt-get update && \
    apt-get source libzip && \
    cd libzip-* && \
    cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=/usr . && \
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
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /libzip-* \
    && rm -rf /tmp/* \
    && apt-get update \
    && apt-get install -y \
    cgroup-tools \
    libcurl4  \
    libevent-2.1-7 \
    libsqlite3-0 \
    libssl3 \
    libsystemd0 \
    liburiparser1 \
    libuuid1 \
    libyaml-0-2 \
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
RUN mkdir -p /etc/greengrass/config.d && \
    echo "---" > /etc/greengrass/config.d/greengrass-lite.yaml && \
    echo "system:" >> /etc/greengrass/config.d/greengrass-lite.yaml && \
    echo "  rootPath: \"/var/lib/greengrass\"" >> /etc/greengrass/config.d/greengrass-lite.yaml && \
    echo "services:" >> /etc/greengrass/config.d/greengrass-lite.yaml && \
    echo "  aws.greengrass.NucleusLite:" >> /etc/greengrass/config.d/greengrass-lite.yaml && \
    echo "    componentType: \"NUCLEUS\"" >> /etc/greengrass/config.d/greengrass-lite.yaml && \
    echo "    configuration:" >> /etc/greengrass/config.d/greengrass-lite.yaml && \
    echo "      runWithDefault:" >> /etc/greengrass/config.d/greengrass-lite.yaml && \
    echo "        posixUser: \"ggcore:ggcore\"" >> /etc/greengrass/config.d/greengrass-lite.yaml && \
    echo "      greengrassDataPlanePort: \"8443\"" >> /etc/greengrass/config.d/greengrass-lite.yaml && \
    echo "      platformOverride: {}" >> /etc/greengrass/config.d/greengrass-lite.yaml

RUN ln -s /etc/greengrass/connection-kit/config.yaml /etc/greengrass/config.yaml

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


CMD ["/lib/systemd/systemd"]
