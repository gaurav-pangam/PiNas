#!/bin/bash
#
# UxPlay AirPlay Server Setup
# Installs and configures UxPlay for AirPlay mirroring/streaming
#

set -e

echo "=========================================="
echo "UxPlay AirPlay Server Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Get the original user (the one who ran sudo)
ORIGINAL_USER="${SUDO_USER:-gaurav}"

echo ""
echo "Installing for user: $ORIGINAL_USER"
echo ""

# ==========================================
# Step 1: Install UxPlay
# ==========================================
echo "Step 1: Installing UxPlay..."
echo ""

# Update package list
apt-get update

# Install uxplay
if dpkg -l | grep -q "^ii  uxplay "; then
    echo "✓ UxPlay is already installed"
else
    echo "Installing UxPlay..."
    apt-get install -y uxplay
    echo "✓ UxPlay installed"
fi

echo ""

# ==========================================
# Step 2: Create systemd service
# ==========================================
echo "Step 2: Creating systemd service..."
echo ""

SERVICE_FILE="/etc/systemd/system/uxplay.service"

cat > "$SERVICE_FILE" << 'EOF'
[Unit]
Description=UxPlay AirPlay Server
After=network.target sound.target

[Service]
Type=simple
User=gaurav
ExecStart=/usr/bin/uxplay -as 0
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Service file created: $SERVICE_FILE"
echo ""

# ==========================================
# Step 3: Configure service (but don't enable)
# ==========================================
echo "Step 3: Configuring service..."
echo ""

# Reload systemd to recognize new service
systemctl daemon-reload

echo "✓ Service configured (not enabled for auto-start)"
echo ""

# ==========================================
# Summary
# ==========================================
echo "=========================================="
echo "✓ UxPlay Setup Complete!"
echo "=========================================="
echo ""
echo "UxPlay AirPlay server is installed and ready to use."
echo ""
echo "To start AirPlay server:"
echo "  sudo systemctl start uxplay.service"
echo ""
echo "To stop AirPlay server:"
echo "  sudo systemctl stop uxplay.service"
echo ""
echo "To check status:"
echo "  sudo systemctl status uxplay.service"
echo ""
echo "To view logs:"
echo "  sudo journalctl -u uxplay.service -f"
echo ""
echo "Note: The service is NOT enabled for auto-start on boot."
echo "      Start it manually when you need to use AirPlay."
echo ""
echo "Once started, you can AirPlay from your iOS/macOS devices"
echo "to this device on the network."
echo ""

