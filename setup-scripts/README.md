# PiNAS Setup Scripts

This directory contains setup scripts to configure a Raspberry Pi as a Network Attached Storage (NAS) device.

## Quick Start

### Fresh Installation

After cloning this repository on a fresh Raspberry Pi OS installation:

```bash
cd PiNAS/setup-scripts
sudo ./00-install-all.sh
```

This will run all setup scripts in order and configure the entire system.

### Updating Existing Installation

To update an already-configured PiNAS system with the latest changes:

```bash
cd PiNAS/setup-scripts
sudo ./99-update.sh
```

This will:

- Pull latest changes from git
- Check and install required system packages (nginx, etc.)
- Update application files
- Restart affected services
- **Safe to run on production systems** (won't touch network/Samba/Tailscale configs)

## Individual Setup Scripts

You can also run individual scripts if you only need specific functionality:

### 0. Update Script (`99-update.sh`)

**For existing installations only** - Updates applications and services without touching system configuration.

- Pulls latest code from git
- Checks and installs required system packages (nginx, etc.)
- Updates application files (fan control, USB mount, etc.)
- Restarts only affected services
- Safe for production systems
- Skips network, Samba, and Tailscale configs

**Usage:**

```bash
sudo ./99-update.sh
```

### 1. Network Configuration (`01-network-config.sh`)

- Sets static IP address: `192.168.0.254/24`
- Gateway: `192.168.0.1`
- DNS: `192.168.0.1`, `8.8.8.8`
- Uses NetworkManager

**Usage:**

```bash
sudo ./01-network-config.sh
```

### 2. USB Auto-Mount (`02-usb-auto-mount-setup.sh`)

- Automatically mounts USB drive on boot
- Device: `/dev/sda1` → `/mnt/usbdrive`
- Supports exFAT filesystem
- Retries mounting with delays (useful for slow USB drives)

**Usage:**

```bash
sudo ./02-usb-auto-mount-setup.sh
```

**Logs:** `/var/log/usb-auto-mount.log`

### 3. Samba File Sharing (`03-samba-setup.sh`)

- Installs and configures Samba
- Creates share: `PiDrive` → `/mnt/usbdrive`
- Installs Avahi for network discovery
- Prompts for Samba password during setup

**Usage:**

```bash
sudo ./03-samba-setup.sh
```

**Access:** `\\192.168.0.254\PiDrive` or `\\raspberrypi\PiDrive`

### 4. Tailscale VPN (`04-tailscale-setup.sh`)

- Installs Tailscale VPN client
- Enables secure remote access
- **Manual step required**: Get auth command from Tailscale dashboard

**Usage:**

```bash
sudo ./04-tailscale-setup.sh
# Then follow the instructions to get auth command from:
# https://login.tailscale.com/admin/machines
```

### 5. Fan Control (`05-fan-control-setup.sh`)

- Hardware PWM-based fan control (GPIO 18)
- Temperature-based speed control
- Fan OFF: < 37°C
- Fan MAX: > 45°C
- Linear scaling between thresholds
- Adds PWM overlay to `/boot/firmware/config.txt`
- **Requires reboot** after first installation

**Usage:**

```bash
sudo ./05-fan-control-setup.sh
```

**Logs:** `/home/gaurav/fan_control_hwpwm.log`

### 6. Nginx Web Server (`06-nginx-setup.sh`)

- Installs nginx web server
- Enables and starts nginx service
- Default configuration listens on port 80
- Can be configured as reverse proxy or static file server

**Usage:**

```bash
sudo ./06-nginx-setup.sh
```

**Config:** `/etc/nginx/sites-available/default`

## Configuration Details

### Network

- Static IP: `192.168.0.254/24`
- Gateway: `192.168.0.1`
- DNS: `192.168.0.1`, `8.8.8.8`

### USB Mount

- Device: `/dev/sda1`
- Mount point: `/mnt/usbdrive`
- Filesystem: exFAT
- Permissions: `uid=1000,gid=1000,umask=000`

### Samba Share

- Share name: `PiDrive`
- Path: `/mnt/usbdrive`
- User: `gaurav`
- Permissions: `0775`

### Fan Control

- GPIO Pin: 18 (Hardware PWM0)
- PWM Frequency: 100Hz
- Temperature thresholds:
  - OFF: ≤ 37°C
  - MAX: ≥ 45°C
  - Linear interpolation between

### Performance Settings (in `/boot/firmware/config.txt`)

```
arm_freq=1200
over_voltage=2
gpu_mem=16
dtoverlay=pwm,pin=18,func=2
```

## Prerequisites

- Raspberry Pi with Raspberry Pi OS (tested on Pi Zero 2W)
- Internet connection for package installation
- USB drive (for NAS functionality)
- Fan connected to GPIO 18 (for fan control)

## Notes

- All scripts are idempotent (safe to run multiple times)
- Scripts will backup configuration files before modifying
- Some scripts require a reboot to take full effect
- The master script (`00-install-all.sh`) will prompt for reboot at the end
- Use `99-update.sh` for updating existing installations

## Troubleshooting

### Check service status:

```bash
sudo systemctl status usb-auto-mount.service
sudo systemctl status fan_control_hwpwm.service
sudo systemctl status smbd
sudo systemctl status tailscaled
sudo systemctl status nginx
```

### View logs:

```bash
sudo tail -f /var/log/usb-auto-mount.log
tail -f ~/fan_control_hwpwm.log
sudo journalctl -u fan_control_hwpwm.service -f
```

### Restart services:

```bash
sudo systemctl restart usb-auto-mount.service
sudo systemctl restart fan_control_hwpwm.service
sudo systemctl restart smbd
```

## Adding New Applications

When adding new applications to PiNAS, update the `99-update.sh` script:

1. Add application files to `applications/` directory
2. Create setup script in `setup-scripts/`
3. Update the appropriate section in `99-update.sh`:

**For applications with files:**

```bash
["app_name"]="applications/source.py|/destination/path|service-name.service|yes/no"
```

**For system packages:**

```bash
PACKAGES=(
    "nginx"
    "package-name"
)
```

4. Update `setup-scripts/README.md` to document the new setup script
5. Update `setup-scripts/00-install-all.sh` to include the new script in the installation sequence

This ensures the update script will manage the new application automatically.
