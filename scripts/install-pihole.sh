#!/bin/sh
# Install Pi-hole on the Luckfox Pico Max (Ubuntu 22.04 built from the SDK) and make sure it
# starts on boot — with systemd if present, otherwise from /etc/rc.local.
#
#   sudo ./install-pihole.sh
#
# Give the board a static address first (static-ip.sh): clients point their DNS at it.
set -eu

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
say()  { printf '%b==>%b %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%b!%b %s\n' "$YELLOW" "$NC" "$*"; }

[ "$(id -u)" -eq 0 ] || { printf '%bRun as root (sudo).%b\n' "$RED" "$NC"; exit 1; }

if ! command -v pihole >/dev/null 2>&1; then
  command -v curl >/dev/null 2>&1 || { say "Installing curl"; apt-get update && apt-get install -y curl; }
  say "Running the official Pi-hole installer (it asks a few questions: interface, upstream DNS, web UI)"
  # https://docs.pi-hole.net/main/basic-install/
  curl -sSL https://install.pi-hole.net | bash
else
  say "Pi-hole is already installed: $(pihole -v 2>/dev/null | head -n 1)"
fi

if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
  say "Enabling pihole-FTL with systemd"
  systemctl daemon-reload
  systemctl enable --now pihole-FTL
  systemctl --no-pager --lines=0 status pihole-FTL || true
else
  warn "No systemd — starting pihole-FTL from /etc/rc.local"
  rc=/etc/rc.local
  [ -f "$rc" ] || printf '#!/bin/sh\nexit 0\n' > "$rc"
  grep -q "pihole-FTL" "$rc" || sed -i '/^exit 0/i /usr/bin/pihole-FTL -f &' "$rc"
  chmod +x "$rc"
  /usr/bin/pihole-FTL -f >/dev/null 2>&1 &
fi

ip=$(hostname -I 2>/dev/null | awk '{print $1}')
say "Done. Web interface: http://${ip:-<board-ip>}/admin"
say "Set the admin password with:  sudo pihole setpassword"
say "Then set ${ip:-this address} as the DNS server in your router (or on each device)."
