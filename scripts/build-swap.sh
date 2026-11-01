#!/bin/bash
# Temporary big swap for compiling on a 256 MB board (zigbee2mqtt, Homebridge, Node.js native modules).
# Turn it off after the build — constant swapping wears out the SD card.
#
#   sudo ./build-swap.sh on [GB]   # default 3 GB, sets vm.swappiness=100
#   sudo ./build-swap.sh off       # removes the file, restores the previous swappiness
#   ./build-swap.sh status
set -euo pipefail

SWAPFILE=/swapfile-build
STATE=/var/lib/build-swap.swappiness

status() {
  free -h
  echo
  swapon --show || true
  echo "vm.swappiness = $(cat /proc/sys/vm/swappiness)"
}

need_root() { [ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }; }

case "${1:-status}" in
  on)
    need_root
    size="${2:-3}"
    [[ "$size" =~ ^[1-8]$ ]] || { echo "Size in GB, 1–8"; exit 1; }
    if swapon --show=NAME --noheadings | grep -qx "$SWAPFILE"; then echo "$SWAPFILE is already active."; status; exit 0; fi
    free_mb=$(df -Pm / | awk 'NR==2 {print $4}')
    (( free_mb > size * 1024 + 512 )) || { echo "Not enough free space on / (${free_mb} MB) for ${size} GB."; exit 1; }
    echo "Creating a ${size} GB swap file at $SWAPFILE (this takes a while on an SD card) …"
    fallocate -l "${size}G" "$SWAPFILE" 2>/dev/null || dd if=/dev/zero of="$SWAPFILE" bs=1M count=$((size * 1024)) status=progress
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE" >/dev/null
    swapon --priority 10 "$SWAPFILE"
    [ -f "$STATE" ] || cat /proc/sys/vm/swappiness > "$STATE"
    sysctl -q vm.swappiness=100
    echo "Done. Build now; run '$0 off' afterwards."
    status
    ;;
  off)
    need_root
    if swapon --show=NAME --noheadings | grep -qx "$SWAPFILE"; then
      echo "Moving pages back and disabling $SWAPFILE …"
      swapoff "$SWAPFILE"
    fi
    rm -f "$SWAPFILE"
    if [ -f "$STATE" ]; then sysctl -q vm.swappiness="$(cat "$STATE")"; rm -f "$STATE"; fi
    echo "Build swap removed."
    status
    ;;
  status) status ;;
  *) echo "Usage: $0 on [GB] | off | status"; exit 1 ;;
esac
