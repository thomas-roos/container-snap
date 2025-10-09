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

## Connection Kit Setup

**Simple 3-Step Process:**

```bash
# 1. Install snap
sudo snap install --dangerous systemd-compose-snap_1.0_amd64.snap

# 2. Load Docker image
sudo docker load -i /snap/systemd-compose-snap/current/docker-compose/systemd-compose-snap/image.tar.gz

# 3. Start container
cd /snap/systemd-compose-snap/current/docker-compose/systemd-compose-snap
sudo SNAP_DATA=/var/snap/systemd-compose-snap/current SNAPCRAFT_PROJECT_NAME=systemd-compose-snap docker-compose --env-file docker-compose.env up -d
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
cd /snap/systemd-compose-snap/x1/docker-compose/systemd-compose-snap
docker-compose down

# Remove snap
sudo snap remove systemd-compose-snap

# Clean up snap directories
sudo rm -rf /snap/systemd-compose-snap
sudo rm -rf /var/snap/systemd-compose-snap

# Clean up docker images (optional)
sudo docker rmi greengrass-lite:latest

# Remove docker volumes (optional - removes all data)
sudo docker volume prune
```

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
