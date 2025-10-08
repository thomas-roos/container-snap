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

## Configuration Management

The snap provides persistent storage for Greengrass configuration and data through volume mappings:

- `/etc/greengrass` → `config/` (certificates, config.yaml)
- `/var/lib/greengrass` → `lib/` (runtime data, logs)
- `/opt/aws/iot/greengrass/components` → `components/` (deployed components)

### Updating Configuration

**1. Direct File System Access (ctrlX CORE):**
```bash
# SSH into ctrlX CORE
ssh boschrexroth@192.168.1.1

# Edit config files directly
sudo nano /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/config/config.yaml
sudo nano /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/config/certificates.pem
```

**2. Container Access:**
```bash
# Access running container
docker exec -it systemd-snap-container /bin/bash

# Edit files inside container (changes persist to host)
nano /etc/greengrass/config.yaml
nano /var/lib/greengrass/deployment.json
```

**3. File Copy Operations:**
```bash
# Copy config files to snap directory
sudo cp my-config.yaml /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/config/
sudo cp certificates/* /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/config/
sudo cp components/*.jar /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/components/
```

**4. Via ctrlX Web Interface:**
- Upload files through ctrlX Device Portal
- Use file manager to navigate to snap directories
- Edit configurations through web-based editors

**5. Automated Deployment:**
```bash
#!/bin/bash
SNAP_DIR="/var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap"
cp connection-kit/* $SNAP_DIR/config/
cp components/* $SNAP_DIR/components/
docker restart systemd-snap-container
```

**6. Using AWS Greengrass Connection Kit:**
```bash
# Copy your AWS connection kit to the config directory
sudo cp GreengrassQuickStartCore-19976cbc5c0-connectionKit.zip \
  /var/snap/systemd-compose-snap/current/docker-volumes/systemd-compose-snap/config/

# Access container and run complete setup
docker exec -it systemd-snap-container /bin/bash

# Inside container - run the complete setup script
cd /snap/systemd-compose-snap/x1/docker-compose/systemd-compose-snap
chmod +x setup-greengrass.sh
./setup-greengrass.sh

# Verify all services are running
systemctl list-units --state=active | grep ggl
```

**Complete Setup Process (Manual):**
```bash
# 1. Download and install Greengrass Lite properly
cd /tmp
wget -O greengrass-lite.zip https://github.com/aws-greengrass/aws-greengrass-lite/releases/download/v2.2.2/aws-greengrass-lite-ubuntu-x86-64.zip
unzip greengrass-lite.zip -d greengrass
cd greengrass

# 2. Install with connection kit
bash install-greengrass-lite.sh -k /etc/greengrass/GreengrassQuickStartCore-19976cbc5c0-connectionKit.zip

# 3. Fix config placeholders
sed -i -e s:{{config_dir}}:\/etc\/greengrass:g -e s:{{nucleus_component}}:aws.greengrass.NucleusLite:g /etc/greengrass/config.yaml

# 4. Fix certificate ownership and permissions
chown ggcore:ggcore /etc/greengrass/*.pem* /etc/greengrass/config.yaml
chmod 644 /etc/greengrass/device.pem.crt /etc/greengrass/AmazonRootCA1.pem
chmod 600 /etc/greengrass/private.pem.key

# 5. Enable and start Greengrass Lite
systemctl enable greengrass-lite.target
systemctl start greengrass-lite.target
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
