# SystemD Container Snap with AWS Greengrass Lite

A provider snap that packages a SystemD container with AWS Greengrass Lite using the Bosch ctrlX docker-compose content interface pattern.

For more details on the Bosch ctrlX container pattern, see: https://docs.automation.boschrexroth.com/doc/2332347265/container-engine-app-basics/latest/en/

## How It Works

This snap implements the **provider** side of the Bosch ctrlX pattern:

**Provider Snap (this project):**
- Packages docker-compose.yml, docker-compose.env, and Dockerfile
- Exposes them via snap content interface at `/snap/systemd-compose-snap/x1/docker-compose/`
- Contains SystemD container with AWS Greengrass Lite (jrei/systemd-ubuntu:24.04 + Greengrass Lite v2.2.2)
- **Does NOT run containers itself**

**Consumer Snap (separate project):**
- Connects to this provider's content interface
- **Executes `docker-compose up -d` from provider's directory**
- Provides runtime commands like `compose-runner.list`

**ctrlX CORE Deployment:**
- **Container Engine app** acts as the consumer
- Reads docker-compose files from provider snaps
- **Manages container lifecycle through web UI**

**Manual Testing:**
- Run `docker-compose up -d` directly since no consumer snap is installed

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

## Connection Kit Setup

**Simple 3-Step Process:**

```bash
# 1. Install snap
sudo snap install --dangerous systemd-compose-snap_1.0_amd64.snap

# 2. Setup connection kit (processes everything on host)
sudo ./setup-connection-kit.sh /path/to/your-connection-kit.zip

# 3. Start container
cd /snap/systemd-compose-snap/x1/docker-compose/systemd-compose-snap
docker-compose up -d
```

The `setup-connection-kit.sh` script automatically:
- Extracts certificates and config files
- Processes config.yaml placeholders  
- Sets correct file permissions
- Prepares everything before container startup

**Important Notes:**
- Connection kits contain sensitive certificates and should NEVER be included in the snap
- Each deployment needs its own unique connection kit from AWS IoT Console
- All processing happens on the host before container starts - no manual fixes needed

## Testing the Container

### Complete Test Flow

```bash
# 1. Install snap
sudo snap install --dangerous systemd-compose-snap_1.0_amd64.snap

# 2. Setup connection kit
sudo ./setup-connection-kit.sh /path/to/your-connection-kit.zip

# 3. Start container
cd /snap/systemd-compose-snap/x1/docker-compose/systemd-compose-snap
docker-compose up -d

# 4. Verify functionality
docker exec systemd-snap-container systemctl status greengrass-lite.target
docker exec systemd-snap-container systemctl list-units --state=active | grep ggl

# 5. Stop container
docker-compose down
```

### Manual Testing (Without Connection Kit)

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

## Configuration Management

The snap provides persistent storage for Greengrass configuration and data through volume mappings:

- `/etc/greengrass` → `config/` (certificates, config.yaml)
- `/var/lib/greengrass` → `lib/` (runtime data, logs)
- `/opt/aws/iot/greengrass/components` → `components/` (deployed components)

### Updating Configuration

**1. Using Setup Script (Recommended):**
```bash
# Replace connection kit
sudo ./setup-connection-kit.sh /path/to/new-connection-kit.zip

# Restart container to pick up changes
cd /snap/systemd-compose-snap/x1/docker-compose/systemd-compose-snap
docker-compose restart
```

**2. Direct File System Access:**
```bash
# Edit config files directly
sudo nano /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/config/config.yaml
sudo nano /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/config/certificates.pem
```

**3. Container Access:**
```bash
# Access running container
docker exec -it systemd-snap-container /bin/bash

# Edit files inside container (changes persist to host)
nano /etc/greengrass/config.yaml
nano /var/lib/greengrass/deployment.json
```

**4. File Copy Operations:**
```bash
# Copy config files to snap directory
sudo cp my-config.yaml /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/config/
sudo cp certificates/* /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/config/
sudo cp components/*.jar /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/components/
```

All changes persist across container restarts and system reboots.

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
