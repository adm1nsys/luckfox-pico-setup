#!/bin/bash

# Create a backup copy of an existing file /etc/network/interfaces
cp /etc/network/interfaces /etc/network/interfaces.backup

# Overwriting the file /etc/network/interfaces with the required configuration
cat <<EOL > /etc/network/interfaces
# interfaces(5) file used by ifup(8) and ifdown(8)
# Include files from /etc/network/interfaces.d:
source /etc/network/interfaces.d/*

auto eth0
iface eth0 inet static
    address 192.168.0.166
    netmask 255.255.255.0
    gateway 192.168.0.1
    dns-nameservers 8.8.8.8 8.8.4.4
EOL

# Let's try to apply the changes without rebooting (if the interface supports it)
if command -v ifdown > /dev/null && command -v ifup > /dev/null; then
    echo "Applying network changes without reboot..."
    ifdown eth0 && ifup eth0
else
    echo "ifdown/ifup commands not found, skipping to reboot."
fi

# Reboot the system to apply the settings
echo "Rebooting system to apply changes..."
sudo reboot
