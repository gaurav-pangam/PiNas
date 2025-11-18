#!/bin/bash
#
# Tailscale VPN Setup Script
# Installs Tailscale for secure remote access
#

set -e

echo "=========================================="
echo "Tailscale VPN Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

echo ""
echo "Installing Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh

echo ""
echo "✓ Tailscale installed"
echo ""
echo "=========================================="
echo "NEXT STEPS:"
echo "=========================================="
echo ""
echo "1. Go to your Tailscale admin console:"
echo "   https://login.tailscale.com/admin/machines"
echo ""
echo "2. Click 'Add Device' or 'Add Machine'"
echo ""
echo "3. Copy the command shown (it will look like):"
echo "   sudo tailscale up --authkey=tskey-auth-xxxxx..."
echo ""
echo "4. Run that command on this Pi"
echo ""
echo "=========================================="
echo ""
echo "Tailscale has been installed but NOT started."
echo "After running the auth command from your dashboard,"
echo "Tailscale will start automatically on boot."
echo ""
echo "Useful commands:"
echo "  tailscale status    - Show connection status"
echo "  tailscale ip        - Show your Tailscale IP"
echo "  tailscale down      - Disconnect from Tailscale"
echo "  tailscale up        - Reconnect to Tailscale"

