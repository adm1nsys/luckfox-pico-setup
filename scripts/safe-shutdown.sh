#!/bin/bash
# Shut the Luckfox Pico Max down without a hard power cut on a mounted SD card.
# Under full load systemd does not manage to stop everything in time, so the heavy services are
# stopped first, one by one, then the data is flushed and the system halted.
# Needs a kernel without the Restart power-off driver (see docs/power-off.md), otherwise it reboots.
#
#   sudo ./safe-shutdown.sh                         # default list below
#   sudo ./safe-shutdown.sh zigbee2mqtt homebridge   # your own list
set -u

DEFAULT_SERVICES=(zigbee2mqtt homebridge mosquitto pihole-FTL docker)
STOP_TIMEOUT=60   # seconds to wait for each service

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }
if [ $# -gt 0 ]; then services=("$@"); else services=("${DEFAULT_SERVICES[@]}"); fi

for svc in "${services[@]}"; do
  systemctl is-active --quiet "$svc" 2>/dev/null || continue
  echo "Stopping $svc …"
  if ! timeout "$STOP_TIMEOUT" systemctl stop "$svc"; then
    echo "  $svc did not stop within ${STOP_TIMEOUT}s — killing it"
    systemctl kill --signal=SIGKILL "$svc" 2>/dev/null
  fi
done

echo "Flushing data to the SD card …"
sync
sleep 2
sync

echo "Halting. Remove power once the console shows 'reboot: System halted'."
# -h is required: plain 'shutdown now' reboots this board
exec shutdown -h now
