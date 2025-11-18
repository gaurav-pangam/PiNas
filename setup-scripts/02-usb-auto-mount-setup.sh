#!/bin/bash
#
# USB Auto-Mount Setup Script
# Installs and configures automatic USB drive mounting service
# Mounts /dev/sda1 to /mnt/usbdrive with exFAT support
#

set -e

echo "=========================================="
echo "USB Auto-Mount Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Get the script directory (where this setup script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Paths
APP_SOURCE="$REPO_ROOT/applications/usb-auto-mount.sh"
APP_DEST="/usr/local/bin/usb-auto-mount.sh"
SERVICE_FILE="/etc/systemd/system/usb-auto-mount.service"

echo ""
echo "Installing dependencies..."
apt update
apt install -y exfat-fuse exfat-utils

echo ""
echo "Installing USB auto-mount script..."
if [ ! -f "$APP_SOURCE" ]; then
    echo "ERROR: Application file not found: $APP_SOURCE"
    exit 1
fi

cp "$APP_SOURCE" "$APP_DEST"
chmod +x "$APP_DEST"
echo "✓ Script installed to $APP_DEST"

echo ""
echo "Creating systemd service..."
cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=Auto mount USB hard drive with retry
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/usb-auto-mount.sh
Restart=no

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Service file created"

echo ""
echo "Creating mount point..."
mkdir -p /mnt/usbdrive
chown -R $SUDO_USER:$SUDO_USER /mnt/usbdrive
echo "✓ Mount point created: /mnt/usbdrive"

echo ""
echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable usb-auto-mount.service
systemctl start usb-auto-mount.service

echo ""
echo "✓ USB Auto-Mount setup complete!"
echo ""
echo "Service status:"
systemctl status usb-auto-mount.service --no-pager -l
echo ""
echo "To view logs: sudo tail -f /var/log/usb-auto-mount.log"

