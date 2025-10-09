#!/bin/bash
set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <connection-kit.zip>"
    echo "Example: $0 /tmp/GreengrassQuickStartCore-123-connectionKit.zip"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONNECTION_KIT="$1"
CONFIG_DIR="/var/snap/greengrass-lite-snap/current/docker-volumes/greengrass-lite-snap/connection-kit"

# Make connection kit path absolute if it's relative
if [[ ! "$CONNECTION_KIT" = /* ]]; then
    CONNECTION_KIT="$(pwd)/$CONNECTION_KIT"
fi

echo "=== Setting up AWS Greengrass Connection Kit ==="

# Check if connection kit exists
if [ ! -f "$CONNECTION_KIT" ]; then
    echo "Error: Connection kit not found: $CONNECTION_KIT"
    exit 1
fi

# Create config directory
echo "Creating config directory..."
mkdir -p "$CONFIG_DIR"

# Extract connection kit
echo "Extracting connection kit..."
cd "$CONFIG_DIR"
unzip -o "$CONNECTION_KIT"

# Fix config placeholders
echo "Processing config.yaml..."
sed -i -e 's:{{config_dir}}:/etc/greengrass/connection-kit:g' -e 's:{{nucleus_component}}:aws.greengrass.NucleusLite:g' config.yaml

# Set proper ownership (ggcore user has UID 998 in container)
echo "Setting file permissions..."
chown 997:997 *.pem* config.yaml
chmod 644 device.pem.crt AmazonRootCA1.pem config.yaml
chmod 600 private.pem.key

echo "=== Connection kit setup complete ==="
echo "Files ready in: $CONFIG_DIR"
