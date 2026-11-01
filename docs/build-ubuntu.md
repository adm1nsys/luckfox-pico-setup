# Building Ubuntu 22.04 for the Luckfox Pico Max

Luckfox removed Ubuntu from its SDK in May 2025 (commit [`d2da6f0`](https://github.com/LuckfoxTECH/luckfox-pico/commit/d2da6f0f4f)), but the last commit before that still builds it. Everything below comes from Luckfox's own public repositories — this guide only pins the right version and adds the fixes.

You need a Linux machine (Ubuntu 22.04 x86-64 works; a VM is fine) with about 40 GB free.

## 1. Get the SDK at the last commit with Ubuntu

```bash
git clone https://github.com/LuckfoxTECH/luckfox-pico.git
cd luckfox-pico
git checkout a984090f0620bf643c990422747d7306f6c82857   # 2025-03-12, "Pullrequest for Luckfox Pico Pi (#246)"
git submodule update --init                            # fetches the Ubuntu root filesystem (luckfox-eng33/pico_ubuntu)
```

Install the build dependencies and the toolchain as described in the [SDK documentation](https://wiki.luckfox.com/Luckfox-Pico-Pro-Max/SDK-Image-Compilation/).

## 2. Pick the board — and double-check it

```bash
./build.sh lunch
```

Choose **Luckfox Pico Max → SD card → Ubuntu**. The matching config is
`project/cfg/BoardConfig_IPC/BoardConfig-SD_CARD-Ubuntu-RV1106_Luckfox_Pico_Max-IPC.mk`
(device tree `rv1106g-luckfox-pico-max.dts`). The menu numbering changes between SDK versions and it is easy to end up with an image for a different board — check the result in step 5 before flashing.

## 3. Stop power-off from rebooting

```bash
./build.sh kernelconfig
```

**Device Drivers → Board level reset or power off → Restart power-off driver** — turn it **off** (`CONFIG_POWER_RESET_RESTART=n`), save and exit. Why, and what it does not fix: [power-off.md](power-off.md).

## 4. Build

```bash
./build.sh
```

The images land in `output/image/`: `env.img`, `idblock.img`, `uboot.img`, `boot.img`, `oem.img`, `userdata.img`, `rootfs.img`, `update.img` and `download.bin`.

## 5. Check the image before flashing

```bash
./scripts/check-image.sh output/image
```

```
Board (device tree):  Luckfox Pico Max
Storage:              SD card
Partitions:           32K(env),512K@32K(idblock),256K(uboot),32M(boot),512M(oem),256M(userdata),6G(rootfs)
Root filesystem:      ext4
System:               Ubuntu 22.04.3 LTS
```

If the board is not *Luckfox Pico Max*, go back to step 2.

## 6. Flash the SD card

- **Windows:** Luckfox's [SocToolKit](https://wiki.luckfox.com/Luckfox-Pico-Pro-Max/Linux-MacOS-Burn-Image/) in SD card mode, with `update.img` or the single images.
- **Linux / macOS:** Luckfox's guide for writing the images from Linux or macOS (per-partition writes at the offsets listed in `sd_update.txt`).

Use a card of 8 GB or more — the root partition alone is 6 GB.

## 7. First boot

- Log in on the serial console (`ttyFIQ0`, 115200) or over SSH as `pico`. The default password in Luckfox's Ubuntu image is `luckfox` — change it right away with `passwd`, and the root password with `sudo passwd root`.
- No USB-UART adapter at hand? [iUART](https://github.com/adm1nsys/ESP32-iUART) turns an ESP32 into a wireless serial console; it started as a debugging tool for exactly this board.
- Continue with [pihole.md](pihole.md).
