#!/bin/bash
#
# Master Setup Script - Runs all setup scripts in order
# This script will configure the entire PiNAS system
#

set -e

echo "=========================================="
echo "PiNAS Complete Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "This will run all setup scripts in order:"
echo "  1. Network Configuration (Static IP)"
echo "  2. USB Auto-Mount"
echo "  3. Samba File Sharing"
echo "  4. Tailscale VPN"
echo "  5. Fan Control (Hardware PWM)"
echo "  6. Nginx Web Server"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
fi

echo ""
echo "=========================================="
echo "Step 1/5: Network Configuration"
echo "=========================================="
bash "$SCRIPT_DIR/01-network-config.sh"

echo ""
echo "=========================================="
echo "Step 2/5: USB Auto-Mount"
echo "=========================================="
bash "$SCRIPT_DIR/02-usb-auto-mount-setup.sh"

echo ""
echo "=========================================="
echo "Step 3/5: Samba File Sharing"
echo "=========================================="
bash "$SCRIPT_DIR/03-samba-setup.sh"

echo ""
echo "=========================================="
echo "Step 4/5: Tailscale VPN"
echo "=========================================="
bash "$SCRIPT_DIR/04-tailscale-setup.sh"

echo ""
echo "=========================================="
echo "Step 5/6: Fan Control"
echo "=========================================="
bash "$SCRIPT_DIR/05-fan-control-setup.sh"

echo ""
echo "=========================================="
echo "Step 6/6: Nginx Web Server"
echo "=========================================="
bash "$SCRIPT_DIR/06-nginx-setup.sh"

echo ""
echo "=========================================="
echo "✓ ALL SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "Summary:"
echo "  ✓ Static IP: 192.168.0.254"
echo "  ✓ USB Auto-Mount: /mnt/usbdrive"
echo "  ✓ Samba Share: \\\\raspberrypi\\PiDrive"
echo "  ✓ Tailscale VPN: Configured"
echo "  ✓ Fan Control: Enabled"
echo "  ✓ Nginx Web Server: Installed"
echo ""
echo "⚠ REBOOT REQUIRED for all changes to take effect"
echo ""
read -p "Reboot now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    reboot
else
    echo "Please reboot manually: sudo reboot"
fi

