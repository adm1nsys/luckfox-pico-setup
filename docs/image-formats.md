# What is inside the SDK's images

The Luckfox SDK produces a set of files that ordinary tools refuse to open — on Linux, macOS and Windows alike. Most of them are not secret, just undocumented Rockchip containers nested inside each other. [`scripts/rkimage.py`](../scripts/rkimage.py) reads all of them, on any OS, with plain Python and no dependencies:

```bash
python3 scripts/rkimage.py info output/image/*.img output/image/download.bin
python3 scripts/rkimage.py extract output/image/update.img unpacked/   # split update.img back into its parts
```

## The files

| File | Starts with | Format | What it is |
|---|---|---|---|
| `update.img` | `RKFW` | Rockchip firmware container | everything in one file for SocToolKit: the USB loader, an `RKAF` package with all partitions, and an MD5 at the end |
| `download.bin` | `LDR ` | Rockchip loader | what the flashing tool uploads to the chip in Maskrom mode: DDR init, a USB helper, and the loader to write to the card |
| `idblock.img` | `RKNS` | Rockchip ID block v2 | the first thing the chip's boot ROM reads from the card: DDR init (TPL) and the SPL loader, with SHA-256 hashes |
| `env.img` | CRC32 + text | U-Boot environment | boot variables — including the partition layout ([storage.md](storage.md)) |
| `uboot.img` | `d00dfeed` | U-Boot FIT | U-Boot and its device tree |
| `boot.img` | `d00dfeed` | U-Boot FIT | the kernel, the board's device tree and a resource blob |
| `oem.img`, `userdata.img`, `rootfs.img` | — | ext4 (SD card) or UBI (SPI NAND) | ordinary filesystems; macOS cannot mount ext4, but `debugfs` from e2fsprogs reads it |

## How they fit together

```
update.img (RKFW)
├── header: build date, chip (RV1106), offsets
├── loader (LDR) ─────────────── = download.bin
│   ├── 471: UsbHead, rv1106_ddr_924MHz_v1     DDR init, run first over USB
│   ├── 472: rv1106_usbplug_v1                 talks to SocToolKit
│   └── loader: FlashHead, FlashData, FlashBoot
├── RKAF package
│   ├── env.img, idblock.img, uboot.img, boot.img
│   ├── oem.img, userdata.img, rootfs.img
│   ├── package-file                            partition → file table
│   └── download.bin
└── MD5 of everything above (32 hex characters)
```

`idblock.img` holds the same two pieces as the loader's *FlashData* (24 KB, DDR init) and *FlashBoot* (158 KB, SPL) — once for the boot ROM on the card, once for flashing over USB.

## Example

`rkimage.py info update.img` on a Buildroot build for the Luckfox Pico:

```
Rockchip firmware (RKFW, update.img) — built 2025-07-29 16:37:13 for RV1106
  loader at 102, 262.4 KB; partition package at 268838, 202.1 MB; 32-byte MD5 trailer
  MD5 c00785f613af7c4ae87343197c687f70 — matches the content

Rockchip loader (LDR) — built 2025-07-29 13:56:04 for RV1106
  signed: no, entries RC4-scrambled: no
  471 (DDR init, run first)                    UsbHead                 2.0 KB  delay 1 ms
  471 (DDR init, run first)                    rv1106_ddr_924MHz_v1   24.0 KB  delay 1 ms
  472 (USB plug, talks to the flashing tool)   rv1106_usbplug_v1      52.0 KB  delay 0 ms
  …
Rockchip partition package (RKAF) — model '-', manufacturer '-'
  env          env.img                        32.0 KB
  idblock      idblock.img                   184.0 KB
  …
  rootfs       rootfs.img                    148.4 MB
```

Extracting that `update.img` gives files byte-for-byte identical to the separate images the SDK writes next to it.

## Sources

The layouts follow open-source code: Rockchip's [rkdeveloptool](https://github.com/rockchip-linux/rkdeveloptool) (`LDR` loader), `afptool` / `img_maker` from Rockchip's [rkbin](https://github.com/rockchip-linux/rkbin) tools (`RKFW`, `RKAF`) and U-Boot's [`tools/rkcommon.c`](https://github.com/u-boot/u-boot/blob/master/tools/rkcommon.c) (`RKNS`). Reading is all `rkimage.py` does — it never changes a file.
