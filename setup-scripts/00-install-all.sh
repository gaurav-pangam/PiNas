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
echo "  7. System Monitor Homepage"
echo "  8. UxPlay AirPlay Server"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
fi

echo ""
echo "=========================================="
echo "Step 1/8: Network Configuration"
echo "=========================================="
bash "$SCRIPT_DIR/01-network-config.sh"

echo ""
echo "=========================================="
echo "Step 2/8: USB Auto-Mount"
echo "=========================================="
bash "$SCRIPT_DIR/02-usb-auto-mount-setup.sh"

echo ""
echo "=========================================="
echo "Step 3/8: Samba File Sharing"
echo "=========================================="
bash "$SCRIPT_DIR/03-samba-setup.sh"

echo ""
echo "=========================================="
echo "Step 4/8: Tailscale VPN"
echo "=========================================="
bash "$SCRIPT_DIR/04-tailscale-setup.sh"

echo ""
echo "=========================================="
echo "Step 5/8: Fan Control"
echo "=========================================="
bash "$SCRIPT_DIR/05-fan-control-setup.sh"

echo ""
echo "=========================================="
echo "Step 6/8: Nginx Web Server"
echo "=========================================="
bash "$SCRIPT_DIR/06-nginx-setup.sh"

echo ""
echo "=========================================="
echo "Step 7/8: System Monitor Homepage"
echo "=========================================="
bash "$SCRIPT_DIR/07-homepage-setup.sh"

echo ""
echo "=========================================="
echo "Step 8/8: UxPlay AirPlay Server"
echo "=========================================="
bash "$SCRIPT_DIR/08-uxplay-setup.sh"

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
echo "  ✓ System Monitor: http://192.168.0.254"
echo "  ✓ UxPlay AirPlay: Ready (start manually)"
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

