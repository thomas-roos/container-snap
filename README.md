# SystemD Container Snap with AWS Greengrass Lite

A provider snap that packages a SystemD container with AWS Greengrass Lite using the Bosch ctrlX docker-compose content interface pattern.

For more details on the Bosch ctrlX container pattern, see: https://docs.automation.boschrexroth.com/doc/2332347265/container-engine-app-basics/latest/en/

## How It Works

This snap implements the **provider** side of the Bosch ctrlX pattern:

**Provider Snap (this project):**
- Packages docker-compose.yml, docker-compose.env, and Dockerfile
- Exposes them via snap content interface at `/snap/greengrass-lite-snap/x1/docker-compose/`
- Contains SystemD container with AWS Greengrass Lite (ubuntu:24.04 + Greengrass Lite git)
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
sudo snap install snapcraft --classic
```
**Important: Logout and login again for docker group changes to take effect**

## Building the Container and Snap

```bash
# Build the container with Greengrass Lite
docker build -t greengrass-lite:latest .

# Save container image for snap packaging
docker save greengrass-lite:latest | gzip > docker-compose/image.tar.gz

# Build the snap
snapcraft pack
```

## Installing the Snap

```bash
## Connection Kit Setup

**Simple 3-Step Process:**

```bash
# 1. Install snap
sudo snap install --dangerous greengrass-lite-snap_1.0_amd64.snap

# 2. Load Docker image
docker load -i /snap/greengrass-lite-snap/current/docker-compose/greengrass-lite-snap/image.tar.gz

# 2. Setup connection kit
./setup-connection-kit.sh /path/to/your-connection-kit.zip

# 3. Start container
cd /snap/greengrass-lite-snap/current/docker-compose/greengrass-lite-snap
docker-compose --env-file docker-compose.env up -d

# 4. Verify functionality
docker exec greengrass-lite systemctl status greengrass-lite.target
docker exec greengrass-lite systemctl list-units --state=active | grep ggl
docker exec greengrass-lite systemctl --failed
docker exec greengrass-lite journalctl -f
docker exec -it greengrass-lite bash

# 5. Stop container
docker-compose down
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

## Uninstall

```bash
# Stop container (if running)
cd /snap/greengrass-lite-snap/x1/docker-compose/greengrass-lite-snap
docker-compose down

# Remove snap
sudo snap remove greengrass-lite-snap

# Clean up snap directories
sudo rm -rf /snap/greengrass-lite-snap
sudo rm -rf /var/snap/greengrass-lite-snap

# Clean up docker images (optional)
sudo docker rmi greengrass-lite:latest

```

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
cd /snap/greengrass-lite-snap/x1/docker-compose/greengrass-lite-snap
docker-compose restart
```

**2. Direct File System Access:**
```bash
# Edit config files directly
sudo nano /var/snap/greengrass-lite-snap/current/docker-volumes/greengrass-lite-snap/config/config.yaml
sudo nano /var/snap/greengrass-lite-snap/current/docker-volumes/greengrass-lite-snap/config/certificates.pem
```
