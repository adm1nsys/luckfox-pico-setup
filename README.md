# luckfox-pico-setup
luckfox pico setup automation files for quick start

## 1_pico_max_subnet.sh

This script configures a static IP on the Ethernet interface of your board. Follow the steps below to ensure everything works correctly:

1. The script modifies the `/etc/network/interfaces` file, which contains settings for IP, DNS, and subnet mask.
2. Make sure `eth0` is the correct Ethernet interface on your board. This script only configures Ethernet interfaces.
3. Ensure that the `address`, `netmask`, and `gateway` values are appropriate for your local network (LAN).
4. After rebooting the board, try to ping it from your computer using `ping X.X.X.X` (replace X.X.X.X with the assigned IP address). Ensure the board is connected to the computer via an Ethernet cable.
5. If the ping is successful, you can connect the board to your router or switch and use it on your network.
6. Once the board is online, you can access it using SSH with `ssh pico@X.X.X.X` (replace X.X.X.X with the assigned IP).

### Note:
- This script creates a backup of the original configuration file at `/etc/network/interfaces.backup` before making changes.
