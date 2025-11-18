# PiNAS Quick Start Guide

## Fresh Installation - One-Command Setup

After cloning this repo on a fresh Raspberry Pi OS:

```bash
cd PiNAS/setup-scripts
sudo ./00-install-all.sh
```

That's it! The script will:

1. ✅ Configure static IP (192.168.0.254)
2. ✅ Setup USB auto-mount
3. ✅ Install and configure Samba
4. ✅ Install Tailscale VPN
5. ✅ Setup hardware PWM fan control

## Updating Existing Installation

To update your already-configured PiNAS with latest changes:

```bash
cd PiNAS/setup-scripts
sudo ./99-update.sh
```

This will:
- Pull latest code from git
- Update application files
- Restart affected services
- **Safe for production** (won't touch network/Samba/Tailscale configs)

## What You'll Need to Provide

During **fresh** setup, you'll be prompted for:

- **Samba password** (for network share access)
- **Tailscale auth command** (get from https://login.tailscale.com/admin/machines)
- **Reboot confirmation** (at the end)

## After Setup

### Access Your NAS

- **Local Network**: `\\192.168.0.254\PiDrive`
- **Username**: `gaurav`
- **Password**: (the Samba password you set)

### Remote Access

- Use Tailscale IP from any device on your Tailscale network
- Check Tailscale IP: `tailscale ip -4`

### Check Status

```bash
# USB mount status
sudo systemctl status usb-auto-mount.service
tail -f /var/log/usb-auto-mount.log

# Fan control status
sudo systemctl status fan_control_hwpwm.service
tail -f ~/fan_control_hwpwm.log

# Samba status
sudo systemctl status smbd

# Tailscale status
tailscale status
```

## Hardware Setup

### Fan Connection

- **GPIO Pin**: 18 (Physical pin 12)
- **Ground**: Any GND pin
- **Power**: 5V or 3.3V depending on your fan

### USB Drive

- Connect USB drive before or after setup
- Will auto-mount to `/mnt/usbdrive`
- Supports exFAT filesystem

## Customization

All configuration is in the setup scripts. Edit before running:

- **Static IP**: Edit `01-network-config.sh`
- **USB device**: Edit `applications/usb-auto-mount.sh` (change `/dev/sda1`)
- **Fan temps**: Edit `applications/fan_control_hwpwm.py` (FAN_OFF_TEMP, MAX_TEMP)
- **Share name**: Edit `03-samba-setup.sh` (SHARE_NAME)

## Troubleshooting

### USB not mounting?

```bash
# Check if device exists
lsblk

# Check logs
sudo tail -f /var/log/usb-auto-mount.log

# Manually test mount
sudo mount -t exfat /dev/sda1 /mnt/usbdrive
```

### Fan not working?

```bash
# Check if PWM is enabled
ls -la /sys/class/pwm/pwmchip0/

# Check service
sudo systemctl status fan_control_hwpwm.service

# Check logs
tail -f ~/fan_control_hwpwm.log

# Verify config.txt has PWM overlay
grep pwm /boot/firmware/config.txt
```

### Can't access Samba share?

```bash
# Check Samba is running
sudo systemctl status smbd

# Test from Pi itself
smbclient -L localhost -U gaurav

# Check firewall (if enabled)
sudo ufw status
```

## Need Help?

See detailed documentation:

- [Setup Scripts README](setup-scripts/README.md)
- [Main README](README.md)
