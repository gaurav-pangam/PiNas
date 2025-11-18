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
- **Automated Setup**: One-command installation of entire system

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
│   ├── README.md                 # Detailed setup documentation
│   └── raw-bash-history.txt      # Original command history
└── README.md              # This file
```

## Quick Start

### Fresh Installation

1. **Flash Raspberry Pi OS** to your SD card
2. **Clone this repository:**
   ```bash
   git clone <repository-url>
   cd PiNAS
   ```
3. **Run the master setup script:**
   ```bash
   cd setup-scripts
   sudo ./00-install-all.sh
   ```
4. **Reboot** when prompted
5. **Access your NAS** via network discovery or `\\192.168.0.254\PiDrive`

### Individual Component Setup

You can also install components individually. See [setup-scripts/README.md](setup-scripts/README.md) for details.

## Applications

### Fan Control (Hardware PWM)

- Temperature-based fan speed control using GPIO 18
- Fan OFF below 37°C, MAX at 45°C
- Linear scaling between thresholds
- 100Hz PWM frequency for silent operation
- Logs to `/home/gaurav/fan_control_hwpwm.log`

### USB Auto-Mount

- Automatically mounts `/dev/sda1` to `/mnt/usbdrive` on boot
- Supports exFAT filesystem
- Retry logic for slow USB drives
- Logs to `/var/log/usb-auto-mount.log`

## System Configuration

### Network

- **Static IP**: 192.168.0.254/24
- **Gateway**: 192.168.0.1
- **DNS**: 192.168.0.1, 8.8.8.8

### Samba Share

- **Share Name**: PiDrive
- **Path**: /mnt/usbdrive
- **User**: gaurav

### Performance Settings

- **CPU Frequency**: 1200 MHz
- **Over Voltage**: +2
- **GPU Memory**: 16 MB (minimal for headless operation)

## Network Access

Once configured, the NAS can be accessed via:

- **Windows**: `\\192.168.0.254\PiDrive` or `\\raspberrypi\PiDrive`
- **macOS**: Finder → Network or `smb://192.168.0.254/PiDrive`
- **Linux**: File Manager → Network or `smb://192.168.0.254/PiDrive`
- **Mobile**: File manager apps with SMB/CIFS support
- **Remote**: Via Tailscale VPN from anywhere

## Troubleshooting

See [setup-scripts/README.md](setup-scripts/README.md) for detailed troubleshooting steps, including:

- Checking service status
- Viewing logs
- Restarting services

## License

This project is open source and available for personal use.
