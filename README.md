# SystemD Container Snap with AWS Greengrass Lite

A provider snap that packages a SystemD container with AWS Greengrass Lite using the Bosch ctrlX docker-compose content interface pattern.

For more details on the Bosch ctrlX container pattern, see: https://docs.automation.boschrexroth.com/doc/2332347265/container-engine-app-basics/latest/en/

## How It Works

This snap implements the **provider** side of the Bosch ctrlX pattern:

**Provider Snap (this project):**
- Packages docker-compose.yml, docker-compose.env, and Dockerfile
- Exposes them via snap content interface at `/snap/systemd-compose-snap/x1/docker-compose/`
- Contains SystemD container with AWS Greengrass Lite (jrei/systemd-ubuntu:24.04 + Greengrass Lite v2.2.2)

**Consumer Snap (separate project):**
- Connects to this provider's content interface
- Executes docker-compose commands from provider's directory
- Provides runtime commands like `compose-runner.list`

**Benefits:**
- Configuration separated from execution
- Multiple consumers can use same provider
- Versioned container definitions
- SystemD + Greengrass Lite works without privileged mode

## Prerequisites

```bash
sudo apt update && sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER
```
**Important: Logout and login again for docker group changes to take effect**

## Build and Install

```bash
# Build provider snap
snapcraft pack

# Install provider snap
sudo snap install --dangerous systemd-compose-snap_1.0_amd64.snap

# Check snap info
systemd-compose-snap.info
```

## Testing the Container

### Test 1: Build and Run Container Directly

```bash
# Navigate to snap's docker-compose directory
cd /snap/systemd-compose-snap/x1/docker-compose/systemd-compose-snap

# Build and start SystemD + Greengrass container
docker-compose up -d

# Test SystemD functionality
docker exec systemd-snap-container systemctl status
docker exec systemd-snap-container systemctl list-units --type=service --state=active

# Test Greengrass Lite installation
docker exec systemd-snap-container dpkg -l | grep greengrass
docker exec systemd-snap-container systemctl list-unit-files | grep ggl

# Interactive access
docker exec -it systemd-snap-container /bin/bash

# Stop container
docker-compose down
```

### Test 2: Manual Testing (Without Snap)

```bash
# Create test directory
mkdir manual-test && cd manual-test

# Copy files from project
cp ../Dockerfile .
cp ../docker-compose/docker-compose.yml .
cp ../docker-compose/docker-compose.env .

# Build and run
docker build -t systemd-greengrass:test .
docker run -d --name test-container --tmpfs /tmp --tmpfs /run --tmpfs /run/lock \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw systemd-greengrass:test

# Test functionality
docker exec test-container systemctl status
docker exec test-container systemctl list-unit-files | grep ggl
docker exec -it test-container /bin/bash

# Cleanup
docker stop test-container && docker rm test-container
```

## With Consumer Snap

```bash
# Install consumer snap (separate project)
sudo snap install --dangerous --devmode compose-runner_1.0_amd64.snap

# Connect snaps
sudo snap connect compose-runner:docker-compose systemd-compose-snap:docker-compose

# Use consumer commands
compose-runner.list
compose-runner.start systemd-compose-snap
compose-runner.stop systemd-compose-snap
```

## ctrlX CORE Deployment

```bash
# Install on ctrlX CORE
sudo snap install --dangerous systemd-compose-snap_1.0_amd64.snap

# Connect to Container Engine
sudo snap connect ctrlx-docker:docker-compose systemd-compose-snap:docker-compose
sudo snap connect ctrlx-docker:docker-volumes systemd-compose-snap:docker-volumes

# Access via ctrlX UI: Container Engine → Images/Containers
```

## What's Included

- **SystemD Runtime**: Full systemd environment as PID 1
- **AWS Greengrass Lite v2.2.2**: IoT edge runtime with services:
  - ggl.core.ggconfigd (configuration management)
  - ggl.core.ggdeploymentd (deployment management)  
  - ggl.core.ggipcd (IPC daemon)
  - ggl.core.ggpubsubd (pub/sub messaging)
  - ggl.core.iotcored (IoT Core connectivity)
- **Bosch ctrlX Pattern**: Content interfaces for docker-compose and volumes

## Manual Testing (Without Snaps)

Create test directory:
```bash
mkdir manual-test && cd manual-test
```

Create docker-compose.yml:
```yaml
version: "3.7"
services:
  systemd-test:
    image: jrei/systemd-ubuntu:24.04
    container_name: manual-systemd-test
    tmpfs:
      - /tmp
      - /run
      - /run/lock
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - test-data:/data
    restart: on-failure
    tty: true
    stdin_open: true

volumes:
  test-data:
    driver: local
```

Run manually:
```bash
docker-compose up -d
docker exec -it manual-systemd-test /bin/bash
docker-compose down
```

## Pattern Benefits

- ✅ Follows Bosch ctrlX docker-compose content interface specification
- ✅ Separates container definitions from runtime
- ✅ Multiple providers can share configurations with consumers
- ✅ SystemD containers work without privileged mode
- ✅ No sudo required after proper docker group setup
- ✅ Clean container lifecycle management
