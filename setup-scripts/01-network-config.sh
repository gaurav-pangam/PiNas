#!/bin/bash
#
# Network Configuration Setup Script
# Sets static IP: 192.168.0.254/24
# Gateway: 192.168.0.1
# DNS: 192.168.0.1, 8.8.8.8
#

set -e

echo "=========================================="
echo "Network Configuration Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Configuration variables
STATIC_IP="192.168.0.254/24"
GATEWAY="192.168.0.1"
DNS="192.168.0.1 8.8.8.8"
CONNECTION_NAME="preconfigured"

echo ""
echo "Configuring static IP address..."
echo "  IP Address: $STATIC_IP"
echo "  Gateway: $GATEWAY"
echo "  DNS: $DNS"
echo ""

# Configure NetworkManager connection
nmcli connection modify "$CONNECTION_NAME" \
    ipv4.addresses "$STATIC_IP" \
    ipv4.gateway "$GATEWAY" \
    ipv4.dns "$DNS" \
    ipv4.method manual \
    ipv4.may-fail yes \
    ipv4.never-default no

echo "✓ Network configuration updated"
echo ""
echo "Restarting NetworkManager..."
systemctl restart NetworkManager

echo ""
echo "✓ Network configuration complete!"
echo ""
echo "Current network status:"
nmcli connection show "$CONNECTION_NAME" | grep -E 'ipv4.addresses|ipv4.gateway|ipv4.dns|ipv4.method'
echo ""
echo "NOTE: You may need to reboot for changes to take full effect"
echo "      Run: sudo reboot"

