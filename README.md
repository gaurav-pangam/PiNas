# PiNAS

A Network Attached Storage (NAS) solution using Raspberry Pi Zero 2W or any Single Board Computer (SBC) running Debian OS.

## Overview

PiNAS transforms a Raspberry Pi or compatible SBC into a fully functional network storage server. It connects to a laptop HDD via USB adapter and shares it over the network using Samba protocol, making it accessible from phones and PCs through network discovery.

## Hardware Requirements

- Raspberry Pi Zero 2W (or any SBC with Debian OS)
- USB HDD adapter
- Laptop HDD
- (Optional) Fan with GPIO connection for cooling

## Features

- **Network Storage**: Share your HDD over the network using Samba protocol
- **Cross-Platform Access**: Access from Windows, macOS, Linux, Android, and iOS devices
- **Auto-Mount**: Automatic USB hard drive detection and mounting with exFAT support
- **Fan Control**: Hardware PWM-based temperature-controlled fan speed (GPIO 18)
- **Static IP**: Configured for reliable network access (192.168.0.254)
- **Remote Access**: Tailscale VPN for secure remote access
- **Web Server**: Nginx web server for hosting web interfaces
- **Automated Setup**: One-command installation of entire system
- **Easy Updates**: Safe update script for existing installations

## Repository Structure

```
PiNAS/
├── applications/          # Application files
│   ├── fan_control_hwpwm.py      # Hardware PWM fan controller
│   └── usb-auto-mount.sh         # USB auto-mount script
├── setup-scripts/         # Setup and installation scripts
│   ├── 00-install-all.sh         # Master setup script (runs all)
│   ├── 01-network-config.sh      # Static IP configuration
│   ├── 02-usb-auto-mount-setup.sh # USB auto-mount setup
│   ├── 03-samba-setup.sh         # Samba file sharing setup
│   ├── 04-tailscale-setup.sh     # Tailscale VPN setup
│   ├── 05-fan-control-setup.sh   # Fan control setup
│   ├── 06-nginx-setup.sh         # Nginx web server setup
│   ├── 99-update.sh              # Update script for existing installations
│   ├── README.md                 # Detailed setup documentation
│   └── raw-bash-history.txt      # Original command history
├── QUICK_START.md         # Quick start guide
└── README.md              # This file
```

## Quick Start

### Fresh Installation

1. **Flash Raspberry Pi OS** to your SD card
2. **Clone this repository:**
   ```bash
   git clone https://github.com/gaurav-pangam/PiNas.git
   cd PiNAS
   ```
3. **Run the master setup script:**
   ```bash
   cd setup-scripts
   sudo ./00-install-all.sh
   ```
4. **Reboot** when prompted

See [QUICK_START.md](QUICK_START.md) for detailed instructions.

### Updating Existing Installation

To update your already-configured PiNAS:

```bash
cd PiNAS/setup-scripts
sudo ./99-update.sh
```

This will:

- Pull latest changes from git
- Check and install required system packages (nginx, etc.)
- Update application files
- Restart affected services
- **Safe for production** (won't modify network/Samba/Tailscale configs)

## What Gets Installed

### Network Configuration

- Static IP: `192.168.0.254/24`
- Gateway: `192.168.0.1`
- DNS: `192.168.0.1`, `8.8.8.8`

### USB Auto-Mount Service

- Automatically mounts `/dev/sda1` to `/mnt/usbdrive`
- Supports exFAT filesystem
- Retries with delays for slow USB drives
- Logs to `/var/log/usb-auto-mount.log`

### Samba File Sharing

- Share name: `PiDrive`
- Path: `/mnt/usbdrive`
- Network discovery via Avahi
- Access: `\\192.168.0.254\PiDrive` or `\\raspberrypi\PiDrive`

### Tailscale VPN

- Secure remote access
- Access your NAS from anywhere
- Manual authentication required during setup

### Hardware PWM Fan Control

- GPIO 18 (Hardware PWM0)
- Temperature-based speed control:
  - OFF: ≤ 37°C
  - MAX: ≥ 45°C
  - Linear scaling between thresholds
- PWM Frequency: 100Hz
- Logs to `/home/gaurav/fan_control_hwpwm.log`

### Nginx Web Server

- Installed and enabled on port 80
- Can be configured as reverse proxy or static file server
- Config: `/etc/nginx/sites-available/default`

## Usage

### Accessing Your NAS

**From Windows:**

```
\\192.168.0.254\PiDrive
```

**From macOS:**

```
smb://192.168.0.254/PiDrive
```

**From Linux:**

```
smb://192.168.0.254/PiDrive
```

**Credentials:**

- Username: `gaurav`
- Password: (set during Samba setup)

### Managing Services

```bash
# Check service status
sudo systemctl status usb-auto-mount.service
sudo systemctl status fan_control_hwpwm.service
sudo systemctl status smbd
sudo systemctl status tailscaled
sudo systemctl status nginx

# Restart services
sudo systemctl restart usb-auto-mount.service
sudo systemctl restart fan_control_hwpwm.service
sudo systemctl restart smbd
sudo systemctl restart nginx

# View logs
sudo tail -f /var/log/usb-auto-mount.log
tail -f ~/fan_control_hwpwm.log
sudo journalctl -u fan_control_hwpwm.service -f
```

## Customization

All scripts are designed to be easily customizable:

- **Static IP**: Edit `setup-scripts/01-network-config.sh`
- **USB Device**: Edit `applications/usb-auto-mount.sh` (change `/dev/sda1`)
- **Fan Temperatures**: Edit `applications/fan_control_hwpwm.py` (FAN_OFF_TEMP, MAX_TEMP)
- **Share Name**: Edit `setup-scripts/03-samba-setup.sh` (SHARE_NAME)

## Adding New Applications

When adding new applications to PiNAS:

1. Add application files to `applications/` directory
2. Create setup script in `setup-scripts/`
3. Update the appropriate section in `setup-scripts/99-update.sh`:

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

4. Update both `README.md` files (root and `setup-scripts/README.md`)
5. Update `setup-scripts/00-install-all.sh` to include the new script

This ensures the update script will manage the new application automatically.

## Documentation

- [Quick Start Guide](QUICK_START.md) - Fast setup instructions
- [Setup Scripts README](setup-scripts/README.md) - Detailed script documentation
- [Raw Bash History](setup-scripts/raw-bash-history.txt) - Original command history

## Troubleshooting

See the [Troubleshooting section](setup-scripts/README.md#troubleshooting) in the setup scripts README.

## License

This project is open source and available for personal and educational use.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## Author

Gaurav Pangam
