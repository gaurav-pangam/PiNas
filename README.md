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
- **Auto-Mount**: Automatic USB hard drive detection and mounting
- **Fan Control**: Hardware PWM-based fan speed control via GPIO
- **System Monitoring**: Web-based task manager showing system stats

## Repository Structure

```
PiNAS/
├── setup-scripts/     # Shell scripts for initial OS setup
├── apps/              # Custom applications
│   ├── fan-controller/           # GPIO-based fan speed controller (Hardware PWM)
│   ├── home-page/                # Web-based system stats dashboard
│   └── usb-hdd-auto-mount/       # Auto-mount scripts for USB drives with Samba integration
```

## Quick Start

1. Flash Debian OS to your SD card
2. Run setup scripts from `setup-scripts/` directory
3. Configure and deploy apps from `apps/` directory
4. Access your NAS through network discovery

## Apps

### Fan Controller
Controls fan speed connected to GPIO pins using hardware PWM for efficient cooling.

### Home Page
A web-based dashboard displaying task manager-like statistics for monitoring system performance.

### USB Hard Drive Auto Mount
Automated scripts to detect, mount USB hard drives, and make them available through Samba shares.

## Network Access

Once configured, the NAS can be accessed via:
- **Windows**: Network Discovery or `\\<pi-hostname>`
- **macOS**: Finder → Network or `smb://<pi-ip-address>`
- **Linux**: File Manager → Network or `smb://<pi-ip-address>`
- **Mobile**: File manager apps with SMB/CIFS support

## License

This project is open source and available for personal use.

