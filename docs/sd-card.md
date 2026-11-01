# Keeping the SD card alive

On the Pico Max the card slot sits directly above the processor. Under load the SoC heats the card, and a hot card that is written to all the time wears out fast — cards in this board died far sooner than in any other device.

What helps:

- **A card made for it.** Use a *high endurance* card (the kind sold for dashcams and surveillance cameras), 8 GB or more. They are rated for continuous writes and higher temperatures.
- **Cooling.** A small heatsink on the processor and some airflow keep both the SoC and the card cooler. Don't put the board in a closed box.
- **Fewer writes.**
  - Keep logs in RAM: in `/etc/systemd/journald.conf` set `Storage=volatile` and `RuntimeMaxUse=16M`.
  - Mount the root filesystem with `noatime` so reading a file does not write to the card (add it to the root entry in `/etc/fstab` or the kernel command line).
  - Pi-hole writes a query database: lower `database.maxDBdays` in `/etc/pihole/pihole.toml` (or under *Settings → All settings* in the web interface), or set it to `0` to turn the long-term database off.
- **Shut down cleanly** — a hard power cut while writing is the fastest way to a broken filesystem. See [power-off.md](power-off.md).
- **Keep a backup image** of a working card, so a dead card means ten minutes of flashing, not a rebuild.
