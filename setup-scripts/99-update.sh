#!/bin/bash
#
# PiNAS Update Script
# Pulls latest changes from git and updates applications/services
# Safe to run on already-configured systems
#

set -e

echo "=========================================="
echo "PiNAS Update Script"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)"
    exit 1
fi

# Get the script directory and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Store original user
ORIGINAL_USER="${SUDO_USER:-gaurav}"

echo ""
echo "Repository: $REPO_ROOT"
echo "User: $ORIGINAL_USER"
echo ""

# ==========================================
# Application Configuration
# Add new applications here as they are added to the project
# ==========================================
declare -A APPS=(
    # Format: ["app_name"]="source_file|destination_file|service_name|needs_executable"
    ["fan_control"]="applications/fan_control_hwpwm.py|/home/$ORIGINAL_USER/fan_control_hwpwm.py|fan_control_hwpwm.service|no"
    ["usb_mount"]="applications/usb-auto-mount.sh|/usr/local/bin/usb-auto-mount.sh|usb-auto-mount.service|yes"
)

# ==========================================
# Step 1: Git Pull
# ==========================================
echo "=========================================="
echo "Step 1: Pulling latest changes from git"
echo "=========================================="

cd "$REPO_ROOT"

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    echo "ERROR: Not a git repository. Please clone from git first."
    exit 1
fi

# Stash any local changes (shouldn't be any, but just in case)
echo "Checking for local changes..."
if ! git diff-index --quiet HEAD --; then
    echo "⚠ Local changes detected, stashing..."
    sudo -u "$ORIGINAL_USER" git stash
    STASHED=true
else
    STASHED=false
fi

# Pull latest changes
echo "Pulling latest changes..."
sudo -u "$ORIGINAL_USER" git pull origin main

if [ $? -ne 0 ]; then
    echo "ERROR: Git pull failed. Please resolve conflicts manually."
    exit 1
fi

echo "✓ Git pull complete"

# ==========================================
# Step 2: Update Applications
# ==========================================
echo ""
echo "=========================================="
echo "Step 2: Updating applications"
echo "=========================================="

UPDATED_SERVICES=()

for app_name in "${!APPS[@]}"; do
    IFS='|' read -r source dest service executable <<< "${APPS[$app_name]}"
    
    echo ""
    echo "Updating: $app_name"
    echo "  Source: $source"
    echo "  Destination: $dest"
    
    # Check if source file exists
    if [ ! -f "$REPO_ROOT/$source" ]; then
        echo "  ⚠ Source file not found, skipping..."
        continue
    fi
    
    # Check if destination exists (service might not be installed)
    if [ ! -f "$dest" ]; then
        echo "  ⚠ Destination not found (service not installed?), skipping..."
        continue
    fi
    
    # Compare files to see if update is needed
    if cmp -s "$REPO_ROOT/$source" "$dest"; then
        echo "  ✓ Already up to date"
    else
        echo "  → Updating file..."
        cp "$REPO_ROOT/$source" "$dest"
        
        # Set executable if needed
        if [ "$executable" = "yes" ]; then
            chmod +x "$dest"
        fi
        
        # Set ownership
        if [[ "$dest" == /home/* ]]; then
            chown "$ORIGINAL_USER:$ORIGINAL_USER" "$dest"
        fi
        
        echo "  ✓ File updated"
        
        # Add to list of services to restart
        if [ -n "$service" ]; then
            UPDATED_SERVICES+=("$service")
        fi
    fi
done

# ==========================================
# Step 3: Restart Services
# ==========================================
if [ ${#UPDATED_SERVICES[@]} -gt 0 ]; then
    echo ""
    echo "=========================================="
    echo "Step 3: Restarting updated services"
    echo "=========================================="
    
    for service in "${UPDATED_SERVICES[@]}"; do
        echo ""
        echo "Restarting: $service"
        
        # Check if service exists and is enabled
        if systemctl is-enabled "$service" &>/dev/null; then
            systemctl restart "$service"
            
            # Check if restart was successful
            if systemctl is-active "$service" &>/dev/null; then
                echo "  ✓ Service restarted successfully"
            else
                echo "  ✗ Service failed to start!"
                echo "  Check logs: sudo journalctl -u $service -n 50"
            fi
        else
            echo "  ⚠ Service not enabled, skipping restart"
        fi
    done
else
    echo ""
    echo "=========================================="
    echo "Step 3: No services need restarting"
    echo "=========================================="
fi

# ==========================================
# Summary
# ==========================================
echo ""
echo "=========================================="
echo "✓ UPDATE COMPLETE!"
echo "=========================================="
echo ""

if [ ${#UPDATED_SERVICES[@]} -gt 0 ]; then
    echo "Updated and restarted services:"
    for service in "${UPDATED_SERVICES[@]}"; do
        echo "  • $service"
    done
else
    echo "No applications were updated (already at latest version)"
fi

echo ""
echo "To check service status:"
echo "  sudo systemctl status fan_control_hwpwm.service"
echo "  sudo systemctl status usb-auto-mount.service"
echo ""

if [ "$STASHED" = true ]; then
    echo "⚠ Note: Local changes were stashed. To restore:"
    echo "  cd $REPO_ROOT && git stash pop"
    echo ""
fi

