#!/bin/bash
#
# Hardware PWM Fan Control Setup Script
# Installs and configures temperature-based fan control using GPIO 18 (PWM0)
# Requires: dtoverlay=pwm,pin=18,func=2 in /boot/firmware/config.txt
#

set -e

echo "=========================================="
echo "Hardware PWM Fan Control Setup"
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
APP_SOURCE="$REPO_ROOT/applications/fan_control_hwpwm.py"
APP_DEST="/home/${SUDO_USER}/fan_control_hwpwm.py"
SERVICE_FILE="/etc/systemd/system/fan_control_hwpwm.service"
CONFIG_FILE="/boot/firmware/config.txt"

echo ""
echo "Installing application..."
if [ ! -f "$APP_SOURCE" ]; then
    echo "ERROR: Application file not found: $APP_SOURCE"
    exit 1
fi

cp "$APP_SOURCE" "$APP_DEST"
chmod +x "$APP_DEST"
chown ${SUDO_USER}:${SUDO_USER} "$APP_DEST"
echo "✓ Fan control script installed to $APP_DEST"

echo ""
echo "Configuring PWM overlay in $CONFIG_FILE..."

# Check if PWM overlay already exists
if grep -q "^dtoverlay=pwm,pin=18,func=2" "$CONFIG_FILE"; then
    echo "⚠ PWM overlay already configured, skipping..."
else
    # Backup config.txt
    if [ ! -f "$CONFIG_FILE.backup" ]; then
        cp "$CONFIG_FILE" "$CONFIG_FILE.backup"
        echo "✓ Backed up $CONFIG_FILE"
    fi
    
    # Add PWM overlay
    echo "dtoverlay=pwm,pin=18,func=2" >> "$CONFIG_FILE"
    echo "✓ Added PWM overlay to $CONFIG_FILE"
fi

echo ""
echo "Checking for performance settings in $CONFIG_FILE..."

# Check and add performance settings if not present
NEEDS_REBOOT=false

if ! grep -q "^arm_freq=1200" "$CONFIG_FILE"; then
    echo "arm_freq=1200" >> "$CONFIG_FILE"
    echo "✓ Added arm_freq=1200"
    NEEDS_REBOOT=true
fi

if ! grep -q "^over_voltage=2" "$CONFIG_FILE"; then
    echo "over_voltage=2" >> "$CONFIG_FILE"
    echo "✓ Added over_voltage=2"
    NEEDS_REBOOT=true
fi

if ! grep -q "^gpu_mem=16" "$CONFIG_FILE"; then
    echo "gpu_mem=16" >> "$CONFIG_FILE"
    echo "✓ Added gpu_mem=16"
    NEEDS_REBOOT=true
fi

echo ""
echo "Creating systemd service..."
cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Raspberry Pi Hardware PWM Fan Control
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $APP_DEST
Restart=always
User=root
WorkingDirectory=/home/${SUDO_USER}

[Install]
WantedBy=multi-user.target
EOF

echo "✓ Service file created"

echo ""
echo "Enabling service..."
systemctl daemon-reload
systemctl enable fan_control_hwpwm.service

echo ""
echo "✓ Fan control setup complete!"
echo ""

if [ "$NEEDS_REBOOT" = true ] || ! grep -q "^dtoverlay=pwm,pin=18,func=2" "$CONFIG_FILE.backup" 2>/dev/null; then
    echo "⚠ REBOOT REQUIRED for PWM overlay to take effect"
    echo ""
    echo "After reboot, start the service with:"
    echo "  sudo systemctl start fan_control_hwpwm.service"
    echo ""
    echo "To reboot now: sudo reboot"
else
    echo "Starting service..."
    systemctl start fan_control_hwpwm.service
    echo ""
    echo "Service status:"
    systemctl status fan_control_hwpwm.service --no-pager -l
fi

echo ""
echo "Fan control configuration:"
echo "  Fan OFF temp: 37°C"
echo "  Max temp (100% speed): 45°C"
echo "  PWM Frequency: 100Hz"
echo "  GPIO Pin: 18 (PWM0)"
echo ""
echo "To view logs: tail -f /home/${SUDO_USER}/fan_control_hwpwm.log"

