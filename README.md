# Ubuntu + Pi-hole on the Luckfox Pico Max

[![Lint](https://github.com/adm1nsys/luckfox-pico-setup/actions/workflows/lint.yml/badge.svg)](https://github.com/adm1nsys/luckfox-pico-setup/actions/workflows/lint.yml)

How to get Ubuntu 22.04 running on the Luckfox Pico Max (Rockchip RV1106) after Luckfox dropped it from its SDK, make the board shut down instead of rebooting, and turn it into a network-wide DNS ad blocker with Pi-hole.

The result of months of work with the board's kernel, root filesystem and SDK — documented so that nobody has to repeat it.

## In short

| | |
|---|---|
| **Board** | Luckfox Pico Max — RV1106, 256 MB RAM, 256 MB SPI NAND, Ethernet; Ubuntu runs from an SD card |
| **System** | Ubuntu 22.04.3 LTS, built from the last Luckfox SDK commit that still includes it |
| **Fix** | kernel option that stops `shutdown` from rebooting the board |
| **Use** | always-on Pi-hole DNS server for the home network |
| **Known limits** | no SPI drivers on Ubuntu; the board cannot cut its own power |

## Guides

1. **[Build Ubuntu for the Pico Max](docs/build-ubuntu.md)** — SDK commit, board config, kernel option, flashing, first boot.
2. **[Why shutdown reboots the board](docs/power-off.md)** — the hardware cause, the kernel fix and how to switch off safely.
3. **[Pi-hole](docs/pihole.md)** — static address, installation, router setup, maintenance.

## Scripts

| Script | What it does |
|---|---|
| [`scripts/check-image.sh`](scripts/check-image.sh) | Reads board name, storage type and partition layout from SDK images — catches images built for the wrong board before flashing. macOS and Linux. |
| [`scripts/static-ip.sh`](scripts/static-ip.sh) | Gives the board a fixed Ethernet address, with validation and a backup of the old config. |
| [`scripts/install-pihole.sh`](scripts/install-pihole.sh) | Installs Pi-hole with the official installer and makes it start on boot (systemd or rc.local). |

## Why this exists

The Pico Max looked like a cheaper alternative to a Raspberry Pi Zero. In practice:

- `shutdown -h now` **reboots** the board. Reading the datasheet showed why: the power-off pin is not connected, and Luckfox's kernel turns every power-off into a restart. Support did not see it as a problem. The fix ended up in the kernel config — see [power-off.md](docs/power-off.md).
- **Ubuntu disappeared** from the official SDK in 2025, and working images were hard to find even on Chinese forums. The SDK history still has it, pinned to the right commit in [build-ubuntu.md](docs/build-ubuntu.md).
- **SPI** works on the vendor's Buildroot image but has no drivers on Ubuntu, with documentation that is partly Chinese and incomplete.
- The SDK's board menu **produced images for the wrong board** — found out only after flashing. Hence `check-image.sh`.

Debugging all of this without a USB-UART adapter at hand led to a side project: **[iUART](https://github.com/adm1nsys/ESP32-iUART)**, a wireless serial console on an ESP32.

## Notes

- Ubuntu images are not distributed here. Everything is built from Luckfox's public repositories ([luckfox-pico](https://github.com/LuckfoxTECH/luckfox-pico), [pico_ubuntu](https://github.com/luckfox-eng33/pico_ubuntu)); this repository contains only documentation and scripts.
- Not affiliated with Luckfox or Canonical. Ubuntu is a trademark of Canonical Ltd.

---

Heorhii Romanenko · [adm1nsys.github.io](https://adm1nsys.github.io/adm1nsys/) · MIT License
