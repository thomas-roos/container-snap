# Container Snap

A snap that runs systemd containers using podman.

## Build

```bash
snapcraft
```

## Install

```bash
sudo snap install --dangerous container-snap_1.0_amd64.snap
```

## Usage

The snap runs as a daemon automatically after installation. The container will start with systemd init.
