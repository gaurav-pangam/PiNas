#!/bin/bash
#
# Nginx Web Server Setup Script
# Installs and enables nginx web server
#

set -e

echo "=========================================="
echo "Nginx Web Server Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (use sudo)"
    exit 1
fi

# Install nginx
echo ""
echo "Installing nginx..."
apt-get update
apt-get install -y nginx

# Enable and start nginx service
echo ""
echo "Enabling and starting nginx service..."
systemctl enable nginx
systemctl start nginx

# Check status
echo ""
echo "Checking nginx status..."
systemctl status nginx --no-pager

echo ""
echo "=========================================="
echo "✓ Nginx Setup Complete!"
echo "=========================================="
echo ""
echo "Nginx is now installed and running"
echo "  - Default config: /etc/nginx/sites-available/default"
echo "  - Listening on port 80"
echo ""
echo "Useful commands:"
echo "  - Check status: sudo systemctl status nginx"
echo "  - Reload config: sudo systemctl reload nginx"
echo "  - View logs: sudo tail -f /var/log/nginx/error.log"
echo ""

