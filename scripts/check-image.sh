#!/bin/bash
# Check which board and storage an SDK image was really built for — before flashing it.
# The SDK's board menu has handed out images for the wrong board; this catches that in seconds.
#
#   ./check-image.sh path/to/output/image
#
# Works on macOS and Linux; reads boot.img and env.img, changes nothing.
set -u

dir="${1:-.}"
boot="$dir/boot.img"; env="$dir/env.img"
[ -f "$boot" ] || { echo "No boot.img in $dir"; exit 1; }

model=$(strings -n 8 "$boot" | grep -oE "Luckfox Pico[ A-Za-z0-9_-]*" | sort -u | head -n 1)
echo "Board (device tree):  ${model:-unknown}"

if [ -f "$env" ]; then
  parts=$(strings -n 6 "$env" | grep -oE "(blkdevparts|mtdparts)=[^ ]*" | head -n 1)
  args=$(strings -n 6 "$env" | grep -oE "sys_bootargs=.*" | head -n 1)
  case "$parts" in
    blkdevparts=mmcblk1*) medium="SD card" ;;
    blkdevparts=mmcblk0*) medium="eMMC" ;;
    mtdparts=spi-nand*)   medium="SPI NAND" ;;
    mtdparts=sfc_nor*)    medium="SPI NOR" ;;
    *)                    medium="unknown" ;;
  esac
  echo "Storage:              $medium"
  echo "Partitions:           ${parts#*:}"
  case "$args" in *ubifs*) fs="UBIFS" ;; *ext4*) fs="ext4" ;; *) fs="unknown" ;; esac
  echo "Root filesystem:      $fs"
fi

if [ -f "$dir/rootfs.img" ] && command -v debugfs >/dev/null 2>&1 && [ "${fs:-}" = ext4 ]; then
  os=$(debugfs -R "cat /usr/lib/os-release" "$dir/rootfs.img" 2>/dev/null | sed -n 's/^PRETTY_NAME="\(.*\)"/\1/p')
  echo "System:               ${os:-unknown}"
fi
