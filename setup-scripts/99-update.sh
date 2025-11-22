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
SCRIPT_PATH="${BASH_SOURCE[0]}"

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

# Homepage is a directory-based application, handled separately
declare -A DIR_APPS=(
    # Format: ["app_name"]="source_dir|destination_dir|service_name"
    ["homepage"]="applications/homepage|/home/$ORIGINAL_USER/applications/homepage|pinas-homepage.service"
)

# ==========================================
# Package Configuration
# Packages that should be installed/updated
# ==========================================
declare -a PACKAGES=(
    "nginx"
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

# Calculate checksum of this script before pull
SCRIPT_CHECKSUM_BEFORE=$(md5sum "$SCRIPT_PATH" | cut -d' ' -f1)

# Pull latest changes
echo "Pulling latest changes..."
sudo -u "$ORIGINAL_USER" git pull origin main

if [ $? -ne 0 ]; then
    echo "ERROR: Git pull failed. Please resolve conflicts manually."
    exit 1
fi

echo "✓ Git pull complete"

# Check if this script itself was updated
SCRIPT_CHECKSUM_AFTER=$(md5sum "$SCRIPT_PATH" | cut -d' ' -f1)

if [ "$SCRIPT_CHECKSUM_BEFORE" != "$SCRIPT_CHECKSUM_AFTER" ] && [ "$PINAS_UPDATE_REEXEC" != "1" ]; then
    echo ""
    echo "⚠ Update script itself was modified!"
    echo "→ Re-executing with new version..."
    echo ""
    export PINAS_UPDATE_REEXEC=1
    exec bash "$SCRIPT_PATH" "$@"
fi

# ==========================================
# Step 2: Update/Install Packages
# ==========================================
echo ""
echo "=========================================="
echo "Step 2: Checking system packages"
echo "=========================================="

for package in "${PACKAGES[@]}"; do
    echo ""
    echo "Checking: $package"

    if dpkg -l | grep -q "^ii  $package "; then
        echo "  ✓ $package is installed"
    else
        echo "  → Installing $package..."
        apt-get install -y "$package"
        echo "  ✓ $package installed"
    fi
done

# ==========================================
# Step 3: Check for New Applications (run setup scripts)
# ==========================================
echo ""
echo "=========================================="
echo "Step 3: Checking for new applications"
echo "=========================================="

# Check if homepage is installed, if not run setup script
if [ ! -d "/home/$ORIGINAL_USER/applications/homepage" ]; then
    echo ""
    echo "New application detected: Homepage"
    if [ -f "$SCRIPT_DIR/07-homepage-setup.sh" ]; then
        echo "  → Running setup script..."
        bash "$SCRIPT_DIR/07-homepage-setup.sh"
        echo "  ✓ Homepage installed"
    else
        echo "  ⚠ Setup script not found, skipping..."
    fi
else
    echo "  ✓ Homepage already installed"
fi

# ==========================================
# Step 3.5: Check Nginx Reverse Proxy Configuration
# ==========================================
echo ""
echo "=========================================="
echo "Step 3.5: Checking nginx reverse proxy"
echo "=========================================="

NGINX_CONFIG="/etc/nginx/sites-available/default"
NEEDS_NGINX_UPDATE=false

# Check if nginx config exists
if [ ! -f "$NGINX_CONFIG" ]; then
    echo "  ⚠ Nginx config not found"
    NEEDS_NGINX_UPDATE=true
else
    # Check if it's configured to proxy to port 8080
    if grep -q "proxy_pass.*127.0.0.1:8080" "$NGINX_CONFIG"; then
        echo "  ✓ Nginx reverse proxy already configured"
    else
        echo "  → Nginx reverse proxy not configured for PiNAS monitor"
        NEEDS_NGINX_UPDATE=true
    fi
fi

# Update nginx config if needed
if [ "$NEEDS_NGINX_UPDATE" = true ]; then
    echo "  → Configuring nginx reverse proxy..."
    cat > "$NGINX_CONFIG" << 'NGINX_EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8080/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX_EOF

    # Test nginx configuration
    if nginx -t 2>/dev/null; then
        systemctl reload nginx
        echo "  ✓ Nginx configured to proxy port 80 → 8080"
    else
        echo "  ✗ Nginx configuration test failed!"
        echo "  Please check: sudo nginx -t"
    fi
fi

# ==========================================
# Step 4: Update Applications
# ==========================================
echo ""
echo "=========================================="
echo "Step 4: Updating applications"
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

# Update directory-based applications
for app_name in "${!DIR_APPS[@]}"; do
    IFS='|' read -r source dest service <<< "${DIR_APPS[$app_name]}"

    echo ""
    echo "Updating: $app_name (directory)"
    echo "  Source: $source"
    echo "  Destination: $dest"

    # Check if source directory exists
    if [ ! -d "$REPO_ROOT/$source" ]; then
        echo "  ⚠ Source directory not found, skipping..."
        continue
    fi

    # Check if destination exists (service might not be installed)
    if [ ! -d "$dest" ]; then
        echo "  ⚠ Destination not found (service not installed?), skipping..."
        continue
    fi

    # Compare directories to see if update is needed
    # Use rsync dry-run to check for differences
    RSYNC_OUTPUT=$(rsync -avn --delete "$REPO_ROOT/$source/" "$dest/" 2>&1)

    # Check if there are any file changes
    # rsync lists files that would be transferred, excluding the summary lines
    FILE_COUNT=$(echo "$RSYNC_OUTPUT" | grep -v "^sending\|^sent\|^total size\|^$\|^\.\/$" | wc -l)

    if [ "$FILE_COUNT" -gt 0 ]; then
        echo "  → Updating directory..."
        rsync -av --delete "$REPO_ROOT/$source/" "$dest/"
        chown -R "$ORIGINAL_USER:$ORIGINAL_USER" "$dest"

        # Make server.py executable if it exists
        if [ -f "$dest/server.py" ]; then
            chmod +x "$dest/server.py"
        fi

        echo "  ✓ Directory updated"

        # Add to list of services to restart
        if [ -n "$service" ]; then
            UPDATED_SERVICES+=("$service")
        fi
    else
        echo "  ✓ Already up to date"
    fi
done

# ==========================================
# Step 5: Restart Services
# ==========================================
if [ ${#UPDATED_SERVICES[@]} -gt 0 ]; then
    echo ""
    echo "=========================================="
    echo "Step 5: Restarting updated services"
    echo "=========================================="
    
    for service in "${UPDATED_SERVICES[@]}"; do
        echo ""
        echo "Restarting: $service"

        # Check if service exists and is enabled
        if systemctl is-enabled "$service" &>/dev/null; then
            # Special handling for pinas-homepage.service - kill any process on port 8080
            if [ "$service" = "pinas-homepage.service" ]; then
                echo "  → Checking for processes on port 8080..."
                PORT_PID=$(netstat -tlnp 2>/dev/null | grep ':8080' | awk '{print $7}' | cut -d'/' -f1)
                if [ -n "$PORT_PID" ]; then
                    echo "  → Killing process $PORT_PID on port 8080..."
                    kill -9 "$PORT_PID" 2>/dev/null || true
                    sleep 1
                fi
            fi

            systemctl restart "$service"

            # Wait a moment for service to start
            sleep 2

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
    echo "Step 5: No services need restarting"
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
echo "Access PiNAS Monitor:"
echo "  http://192.168.0.254 (via nginx proxy)"
echo "  http://192.168.0.254:8080 (direct)"
echo ""
echo "To check service status:"
echo "  sudo systemctl status fan_control_hwpwm.service"
echo "  sudo systemctl status usb-auto-mount.service"
echo "  sudo systemctl status pinas-homepage.service"
echo "  sudo systemctl status nginx.service"
echo ""

if [ "$STASHED" = true ]; then
    echo "⚠ Note: Local changes were stashed. To restore:"
    echo "  cd $REPO_ROOT && git stash pop"
    echo ""
fi

