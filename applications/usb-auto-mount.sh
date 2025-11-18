#!/bin/bash
LOGFILE="/var/log/usb-auto-mount.log"
MOUNTPOINT="/mnt/usbdrive"
DEVICE="/dev/sda1"
RETRIES=100
DELAY=10

mkdir -p "$MOUNTPOINT"
echo "==== $(date) : Starting USB auto-mount ====" >> "$LOGFILE"

# Wait ~2–3 minutes after boot
sleep 20

for ((i=1; i<=RETRIES; i++)); do
    if [ -b "$DEVICE" ]; then
        echo "$(date): Attempt $i - Found $DEVICE, mounting..." >> "$LOGFILE"
        if mountpoint -q "$MOUNTPOINT"; then
            echo "$(date): Already mounted." >> "$LOGFILE"
            exit 0
        fi
       sudo mount -t exfat -o rw,uid=1000,gid=1000,umask=000 "$DEVICE" "$MOUNTPOINT" && {
            echo "$(date): Mounted successfully on $MOUNTPOINT" >> "$LOGFILE"
            chown -R gaurav:gaurav "$MOUNTPOINT"
            exit 0
        }
        echo "$(date): Mount failed, retrying..." >> "$LOGFILE"
    else
        echo "$(date): Attempt $i - Device not found, retrying..." >> "$LOGFILE"
    fi
    sleep "$DELAY"
done

echo "$(date): Failed to mount after $RETRIES attempts." >> "$LOGFILE"
exit 1

