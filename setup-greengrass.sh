#!/bin/bash
# Setup script for AWS Greengrass Lite in SystemD container

echo "=== AWS Greengrass Lite Setup ==="

# Download and install Greengrass Lite
cd /tmp
wget -O greengrass-lite.zip https://github.com/aws-greengrass/aws-greengrass-lite/releases/download/v2.2.2/aws-greengrass-lite-ubuntu-x86-64.zip
unzip greengrass-lite.zip -d greengrass
cd greengrass

# Install with connection kit
bash install-greengrass-lite.sh -k /etc/greengrass/GreengrassQuickStartCore-19976cbc5c0-connectionKit.zip

# Fix config placeholders
sed -i -e s:{{config_dir}}:\/etc\/greengrass:g -e s:{{nucleus_component}}:aws.greengrass.NucleusLite:g /etc/greengrass/config.yaml

# Fix certificate ownership
chown ggcore:ggcore /etc/greengrass/device.pem.crt
chown ggcore:ggcore /etc/greengrass/private.pem.key
chown ggcore:ggcore /etc/greengrass/AmazonRootCA1.pem
chown ggcore:ggcore /etc/greengrass/config.yaml

# Set proper permissions
chmod 644 /etc/greengrass/device.pem.crt
chmod 600 /etc/greengrass/private.pem.key
chmod 644 /etc/greengrass/AmazonRootCA1.pem

# Enable and start Greengrass Lite
systemctl enable greengrass-lite.target
systemctl start greengrass-lite.target

echo "=== Greengrass Lite setup complete ==="
echo "Check status with: systemctl status greengrass-lite.target"
