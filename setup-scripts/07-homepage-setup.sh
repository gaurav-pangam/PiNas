#!/bin/bash
#
# PiNAS System Monitor Homepage Setup Script
# Installs and configures the web-based system monitoring dashboard
# Accessible at http://192.168.0.254:8080
#

set -e

echo "=========================================="
echo "PiNAS System Monitor Homepage Setup"
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
APP_SOURCE_DIR="$REPO_ROOT/applications/homepage"
APP_DEST_DIR="/home/${SUDO_USER}/applications/homepage"
SERVICE_FILE="/etc/systemd/system/pinas-homepage.service"

echo ""
echo "Installing homepage application..."
if [ ! -d "$APP_SOURCE_DIR" ]; then
    echo "ERROR: Application directory not found: $APP_SOURCE_DIR"
    exit 1
fi

# Create applications directory if it doesn't exist
mkdir -p "$(dirname "$APP_DEST_DIR")"

# Copy the entire homepage directory
cp -r "$APP_SOURCE_DIR" "$APP_DEST_DIR"
chown -R ${SUDO_USER}:${SUDO_USER} "$APP_DEST_DIR"
chmod +x "$APP_DEST_DIR/server.py"
echo "✓ Homepage files installed to $APP_DEST_DIR"

echo ""
echo "Creating systemd service..."
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=PiNAS System Monitor Homepage
After=network.target

[Service]
Type=simple
User=${SUDO_USER}
WorkingDirectory=$APP_DEST_DIR
ExecStart=/usr/bin/python3 $APP_DEST_DIR/server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Service file created"

echo ""
echo "Enabling and starting service..."
systemctl daemon-reload
systemctl enable pinas-homepage.service
systemctl start pinas-homepage.service

echo ""
echo "✓ PiNAS Homepage setup complete!"
echo ""
echo "Service status:"
systemctl status pinas-homepage.service --no-pager -l

echo ""
echo "=========================================="
echo "Access the homepage at:"
echo "  http://192.168.0.254:8080"
echo "  http://$(hostname -I | awk '{print $1}'):8080"
echo "=========================================="
echo ""
echo "Features:"
echo "  - CPU Temperature & Fan Speed"
echo "  - CPU Frequency (per-core)"
echo "  - RAM Usage"
echo "  - Network Statistics"
echo "  - Top Processes"
echo "  - Configurable refresh rate (1-30 seconds)"
echo ""
echo "Useful commands:"
echo "  - Check status: sudo systemctl status pinas-homepage"
echo "  - Restart: sudo systemctl restart pinas-homepage"
echo "  - View logs: sudo journalctl -u pinas-homepage -f"
echo ""

