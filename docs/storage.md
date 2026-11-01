# The SD card layout — and why your PC can't see it

## No partition table

A card flashed by the Luckfox SDK has **no MBR or GPT partition table**. The layout is a string in `env.img` that the bootloader passes to the kernel:

```
blkdevparts=mmcblk1:32K(env),512K@32K(idblock),256K(uboot),32M(boot),512M(oem),256M(userdata),6G(rootfs)
```

The kernel knows the partitions; nothing else does. Put the card into a Linux, macOS or Windows machine and it shows up as raw or unallocated space — there is simply no table those systems could read. (`scripts/check-image.sh` prints this layout from an image.)

It also means the images can only be written the way the SDK expects: SocToolKit on Windows, or per-partition writes at the offsets in `sd_update.txt` — while the images themselves can only be built on Linux.

## Only 8 GB of a 64 GB card

The Ubuntu board config gives the root partition a fixed **6 GB**. Everything after it on the card stays unused — with a 64 GB card, 56 GB are never touched. On first boot Luckfox's `/usr/bin/filesystem_resize.sh` runs `resize2fs` on partitions 5–7, but that only grows each filesystem to the size of its *partition*, not to the end of the card.

A few gigabytes fill up quickly: `apt update && apt upgrade`, a Node.js build, Pi-hole's databases, swap. Adding space on the running system is risky: there is no partition table to edit with normal tools, the root partition cannot be moved or grown while it is mounted in that position, and a new partition has to be defined in `env.img` and created while the system writes logs in the background. On a card that may already be failing ([sd-card.md](sd-card.md)), one interrupted write is enough to lose it.

## Better: decide before building

Set the root partition to take the rest of the card **in the board config, before building** — `-` instead of a size means "up to the end", the same syntax as the kernel's `mtdparts`:

```make
# project/cfg/BoardConfig_IPC/BoardConfig-SD_CARD-Ubuntu-RV1106_Luckfox_Pico_Max-IPC.mk
export RK_PARTITION_CMD_IN_ENV="32K(env),512K@32K(idblock),256K(uboot),32M(boot),512M(oem),256M(userdata),-(rootfs)"
```

On first boot `filesystem_resize.sh` then grows the root filesystem over the whole card.

> Not tested on my board — I learned about the layout the hard way, on a running system. Check the result with `./scripts/check-image.sh output/image` (the partitions line should end in `-(rootfs)`) and keep a backup of the card.

## Swap is created for you

The same `filesystem_resize.sh` also creates a permanent **1 GB swap file** (`/swapfile`, added to `/etc/fstab`) on first boot. With 256 MB of RAM some swap is needed, but this one sits on the SD card. To move to compressed swap in RAM instead, see [memory.md](memory.md#everyday-zram).
