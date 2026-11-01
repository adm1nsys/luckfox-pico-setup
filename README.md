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
| **Known limits** | 256 MB RAM (swap needed); no SPI drivers on Ubuntu; the board cannot cut its own power; the SD card overheats |

## Guides

1. **[Build Ubuntu for the Pico Max](docs/build-ubuntu.md)** — SDK commit, board config, kernel option, flashing, first boot.
2. **[Shutting down without breaking it](docs/power-off.md)** — why shutdown reboots, the kernel fix, and what goes wrong under load.
3. **[Pi-hole](docs/pihole.md)** — static address, installation, router setup, maintenance.
4. **[Living with 256 MB of RAM](docs/memory.md)** — zram for every day, a big temporary swap for building zigbee2mqtt or Homebridge.
5. **[Keeping the SD card alive](docs/sd-card.md)** — the card sits above the processor; cooling and fewer writes.

## Scripts

| Script | What it does |
|---|---|
| [`scripts/check-image.sh`](scripts/check-image.sh) | Reads board name, storage type and partition layout from SDK images — catches images built for the wrong board before flashing. macOS and Linux. |
| [`scripts/static-ip.sh`](scripts/static-ip.sh) | Gives the board a fixed Ethernet address, with validation and a backup of the old config. |
| [`scripts/install-pihole.sh`](scripts/install-pihole.sh) | Installs Pi-hole with the official installer and makes it start on boot (systemd or rc.local). |
| [`scripts/build-swap.sh`](scripts/build-swap.sh) | Adds a big temporary swap file with aggressive swapping for compiling Node.js projects, and removes it afterwards. |
| [`scripts/safe-shutdown.sh`](scripts/safe-shutdown.sh) | Stops heavy services one by one, flushes the SD card and halts — so a busy board doesn't end up with a hard power cut. |

## Why this exists

The Pico Max looked like a cheaper alternative to a Raspberry Pi Zero. In practice:

- `shutdown now` and `poweroff` **reboot** the board. Reading the datasheet showed why: the power-off pin is not connected, and Luckfox's kernel turns every power-off into a restart. Support did not see it as a problem. The fix ended up in the kernel config — and even then, with zigbee2mqtt and Homebridge pushing the board to full load, every second shutdown ended in a hard power cut. See [power-off.md](docs/power-off.md).
- **256 MB of RAM** is not enough for Ubuntu with a few services: it ran with a 1 GB swap file, and building zigbee2mqtt needed several gigabytes of aggressive swap — see [memory.md](docs/memory.md).
- The **SD card sits right above the processor**, gets hot and dies early — and swap on it makes that worse. See [sd-card.md](docs/sd-card.md).
- **Ubuntu disappeared** from the official SDK in 2025, and working images were hard to find even on Chinese forums. The SDK history still has it, pinned to the right commit in [build-ubuntu.md](docs/build-ubuntu.md).
- **SPI** works on the vendor's Buildroot image but has no drivers on Ubuntu, with documentation that is partly Chinese and incomplete.
- The SDK's board menu **produced images for the wrong board** — found out only after flashing. Hence `check-image.sh`.

Debugging all of this without a USB-UART adapter at hand led to a side project: **[iUART](https://github.com/adm1nsys/ESP32-iUART)**, a wireless serial console on an ESP32.

## Notes

- Ubuntu images are not distributed here. Everything is built from Luckfox's public repositories ([luckfox-pico](https://github.com/LuckfoxTECH/luckfox-pico), [pico_ubuntu](https://github.com/luckfox-eng33/pico_ubuntu)); this repository contains only documentation and scripts.
- Not affiliated with Luckfox or Canonical. Ubuntu is a trademark of Canonical Ltd.

---

Heorhii Romanenko · [adm1nsys.github.io](https://adm1nsys.github.io/adm1nsys/) · MIT License
