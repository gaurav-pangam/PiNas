#!/bin/bash
#
# Samba File Sharing Setup Script
# Configures Samba to share /mnt/usbdrive as "PiDrive"
#

set -e

echo "=========================================="
echo "Samba File Sharing Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Configuration
SHARE_NAME="PiDrive"
SHARE_PATH="/mnt/usbdrive"
SAMBA_USER="${SUDO_USER:-gaurav}"

echo ""
echo "Installing Samba and Avahi (for network discovery)..."
apt update
apt install -y samba avahi-daemon

echo ""
echo "Configuring Samba share..."
echo "  Share Name: $SHARE_NAME"
echo "  Share Path: $SHARE_PATH"
echo "  User: $SAMBA_USER"

# Backup original config if it exists and hasn't been backed up
if [ -f /etc/samba/smb.conf ] && [ ! -f /etc/samba/smb.conf.backup ]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup
    echo "✓ Backed up original smb.conf"
fi

# Check if share already exists
if grep -q "\[$SHARE_NAME\]" /etc/samba/smb.conf 2>/dev/null; then
    echo "⚠ Share [$SHARE_NAME] already exists in smb.conf, skipping..."
else
    # Add share configuration
    cat >> /etc/samba/smb.conf << EOF

[$SHARE_NAME]
   path = $SHARE_PATH
   browseable = yes
   writeable = yes
   only guest = no
   create mask = 0775
   directory mask = 0775
   valid users = $SAMBA_USER
EOF
    echo "✓ Added [$SHARE_NAME] share to smb.conf"
fi

echo ""
echo "Setting up Samba user: $SAMBA_USER"
echo "Please enter a password for Samba access:"
smbpasswd -a "$SAMBA_USER"

echo ""
echo "Restarting Samba service..."
systemctl restart smbd
systemctl enable smbd

echo ""
echo "Enabling Avahi for network discovery..."
systemctl enable avahi-daemon
systemctl start avahi-daemon

echo ""
echo "✓ Samba setup complete!"
echo ""
echo "Share details:"
echo "  Network path: \\\\$(hostname)\\$SHARE_NAME"
echo "  or: \\\\192.168.0.254\\$SHARE_NAME"
echo "  Username: $SAMBA_USER"
echo ""
echo "Service status:"
systemctl status smbd --no-pager -l | head -10

