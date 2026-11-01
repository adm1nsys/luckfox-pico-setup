# Shutting down the Luckfox Pico Max without breaking it

## Symptom

With Luckfox's default kernel the board cannot be switched off from software:

| Command | Result |
|---|---|
| `shutdown now` | reboots |
| `poweroff` | reboots |
| `shutdown -h now` | halts only with the kernel fix below — and only if the system manages to stop everything in time |

## Cause

Two things come together:

1. **The hardware cannot switch itself off.** The Pico Max has no PMIC power-off path: the pin that would request power-off is left unconnected on the board, so nothing can actually cut the supply. The datasheet shows it; Luckfox support did not treat it as a bug.
2. **The kernel turns "power off" into "restart".** Luckfox's kernel config enables the *Restart power-off driver* (`CONFIG_POWER_RESET_RESTART=y` in `luckfox_rv1106_linux_defconfig`). When nothing else can power the board off, this driver handles every power-off request by restarting the system.

## Fix in the kernel

Disable the driver before building (see [build-ubuntu.md](build-ubuntu.md), step 3):

```
Device Drivers
  → Board level reset or power off
    → [ ] Restart power-off driver        # CONFIG_POWER_RESET_RESTART=n
```

![Kernel menuconfig: Restart power-off driver disabled](img/kernel-power-off.png)

Now a power-off request halts the system instead of restarting it. The board itself stays powered — there is no switch to open — so "off" means *halted, safe to unplug*.

## Under load it still goes wrong

With 256 MB of RAM and a single core, the board is easily at full load. In my setup it ran Pi-hole, **zigbee2mqtt** and **Homebridge**; at around 100 % CPU, `shutdown -h now` failed roughly every second time: services did not stop within systemd's timeouts, the shutdown never reached the point where filesystems are unmounted — and the next thing was a hard power cut on a mounted SD card.

So a clean shutdown needs three things: the kernel fix, the heavy services stopped *before* shutting down, and the right command.

```bash
sudo ./scripts/safe-shutdown.sh                        # default list of heavy services
sudo ./scripts/safe-shutdown.sh zigbee2mqtt homebridge  # or name them yourself
```

[`safe-shutdown.sh`](../scripts/safe-shutdown.sh) stops the named services one by one and waits for each, flushes everything to the SD card with `sync`, then runs `shutdown -h now`. Wait until the serial console shows `reboot: System halted` and only then remove power.

By hand it is the same:

```bash
sudo systemctl stop zigbee2mqtt homebridge pihole-FTL
sync
sudo shutdown -h now
```

## Also seen on the way

- **The SD card overheats.** The card slot sits right above the processor, so the card gets hot under load and dies early — see [sd-card.md](sd-card.md).
- **SPI on Ubuntu:** the SPI peripherals that work on Luckfox's Buildroot image have no working drivers in the Ubuntu build, and the vendor documentation is partly Chinese and incomplete. Writing those drivers was out of scope, so this Ubuntu image is used without SPI.
- **Wrong board in the SDK menu:** building with the SDK's board menu has produced images for a different board than selected — after hours of building. [`scripts/check-image.sh`](../scripts/check-image.sh) reads the board name and storage layout straight from the image, so this is caught before flashing.
