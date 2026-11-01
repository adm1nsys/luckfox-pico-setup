# Pi-hole on the Luckfox Pico Max

A network-wide ad and tracker blocker: the board answers DNS for every device in the network and drops requests to known ad and tracking domains. The Pico Max is small, draws very little power and has Ethernet — a good fit for an always-on DNS server.

This is the easy part. Once Ubuntu runs ([build-ubuntu.md](build-ubuntu.md)), the board is, for Pi-hole, just a small Linux machine like a Raspberry Pi Zero: the same official instructions work one to one, with no board-specific workarounds. What the board adds is around Pi-hole, not in it — a fixed address, little RAM ([memory.md](memory.md)) and a careful shutdown ([power-off.md](power-off.md)).

Tested with Pi-hole v6 (Core 6.1, Web 6.2) on that Ubuntu 22.04 only — not on Luckfox's Buildroot or other images.

## 1. Fixed address

Clients need to find the DNS server at the same address every time:

```bash
sudo ./scripts/static-ip.sh 192.168.0.200/24 192.168.0.1
```

Arguments: address/prefix, gateway, optionally the DNS server for the board itself (default `1.1.1.1`) and the interface (default `eth0`). The old `/etc/network/interfaces` is kept as a backup. Alternatively reserve the address in your router's DHCP settings.

## 2. Install

```bash
sudo ./scripts/install-pihole.sh
```

It runs the [official Pi-hole installer](https://docs.pi-hole.net/main/basic-install/) and makes sure `pihole-FTL` starts on boot — through systemd, or through `/etc/rc.local` on systems without it.

```bash
sudo pihole setpassword       # admin password for the web interface
```

The web interface is at `http://192.168.0.200/admin`.

## 3. Use it

Set the board's address as the DNS server in your router's DHCP settings, so every device picks it up automatically — or set it manually on single devices.

## Maintenance

Pi-hole installs its own cron jobs: the blocklists are refreshed weekly (`pihole updateGravity`), logs are rotated and updates are checked daily. Useful commands:

```bash
pihole status
pihole -up            # update Pi-hole
pihole -g             # refresh blocklists now
pihole tail           # live DNS log
```

To switch the board off safely, see [power-off.md](power-off.md#what-it-does-not-fix).
