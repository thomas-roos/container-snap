#!/bin/bash
# Setup script for AWS Greengrass Lite - runs inside container

echo "=== AWS Greengrass Lite Setup ==="

# Check if connection kit exists
if [ ! -f /etc/greengrass/*.zip ]; then
    echo "No connection kit found - Greengrass will run without AWS connection"
    exit 0
fi

echo "=== Processing connection kit ==="
cd /etc/greengrass
unzip -o *.zip

echo "=== Fixing config placeholders ==="
sed -i -e 's:{{config_dir}}:/etc/greengrass:g' -e 's:{{nucleus_component}}:aws.greengrass.NucleusLite:g' config.yaml

echo "=== Setting certificate permissions ==="
chown ggcore:ggcore *.pem* config.yaml
chmod 644 device.pem.crt AmazonRootCA1.pem
chmod 600 private.pem.key

echo "=== Starting Greengrass Lite ==="
systemctl enable greengrass-lite.target
systemctl start greengrass-lite.target

echo "=== Greengrass Lite setup complete ==="
