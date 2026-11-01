#!/bin/bash
# Give the board a fixed address on Ethernet (Ubuntu with ifupdown, as built by the Luckfox SDK).
# A DNS server like Pi-hole needs one, so clients can always find it.
#
#   sudo ./static-ip.sh 192.168.0.200/24 192.168.0.1 [dns] [interface]
#
# The current /etc/network/interfaces is backed up first.
set -euo pipefail

usage() { echo "Usage: sudo $0 ADDRESS/PREFIX GATEWAY [DNS (default 1.1.1.1)] [INTERFACE (default eth0)]"; exit 1; }
[ $# -ge 2 ] || usage
[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }

cidr="$1"; gateway="$2"; dns="${3:-1.1.1.1}"; iface="${4:-eth0}"
ip_re='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
address="${cidr%/*}"; prefix="${cidr#*/}"
[[ "$address" =~ $ip_re && "$gateway" =~ $ip_re && "$dns" =~ $ip_re ]] || { echo "Addresses must look like 192.168.0.200"; exit 1; }
[[ "$prefix" =~ ^[0-9]+$ && "$prefix" -ge 8 && "$prefix" -le 30 ]] || { echo "Prefix must be 8–30, e.g. /24"; exit 1; }
ip link show "$iface" >/dev/null 2>&1 || { echo "No interface $iface (see: ip -br link)"; exit 1; }

# /24 -> 255.255.255.0
mask=$(( 0xffffffff << (32 - prefix) & 0xffffffff ))
netmask="$(( mask >> 24 & 255 )).$(( mask >> 16 & 255 )).$(( mask >> 8 & 255 )).$(( mask & 255 ))"

cfg=/etc/network/interfaces
cp "$cfg" "$cfg.backup.$(date +%Y%m%d-%H%M%S)"

cat > "$cfg" <<EOF
# written by static-ip.sh — previous version saved next to this file
source /etc/network/interfaces.d/*

auto lo
iface lo inet loopback

auto $iface
iface $iface inet static
    address $address
    netmask $netmask
    gateway $gateway
    dns-nameservers $dns
EOF

echo "Static address $address/$prefix on $iface (gateway $gateway, DNS $dns)."
if command -v ifdown >/dev/null && command -v ifup >/dev/null; then
  echo "Applying now — an SSH session over $iface will drop; reconnect to $address."
  ifdown "$iface" 2>/dev/null || true
  ifup "$iface"
else
  echo "Reboot to apply: sudo reboot"
fi
