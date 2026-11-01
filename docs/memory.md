# Living with 256 MB of RAM

The Pico Max has 256 MB of RAM, and Ubuntu with a few services does not fit into that. Without swap the kernel's OOM killer starts ending processes; with the wrong swap the SD card pays for it. Ubuntu offers three kinds — use them for different jobs.

| Kind | Where it lives | Good for | On this board |
|---|---|---|---|
| **zram** | compressed, in RAM | everyday use | ✅ no writes to the card; pages are compressed 2–3×, so the same RAM holds more |
| **swap file** | a file on the SD card | rare peaks, building software | ⚠️ only temporarily — constant swapping wears out a card that already runs hot ([sd-card.md](sd-card.md)) |
| **swap partition** | its own partition on the card | — | ❌ same wear as a swap file, and the partition layout is fixed by the SDK |

## Everyday: zram

```bash
sudo apt install zram-config        # Ubuntu's package: sets up compressed swap in RAM on every boot
sudo reboot
swapon --show                       # /dev/zram0 should be listed
```

A permanent 1 GB swap file on the card — which is what I ran at first, because the board kept running out of memory — works, but it is the fastest way to a dead card.

## Building software: a big temporary swap file

zigbee2mqtt and Homebridge (and many of their plugins) are Node.js projects; `npm install` compiles native modules and needs far more than 256 MB. With too little swap, Node runs out of memory and the build dies halfway. What works: a **2–4 GB swap file and the most aggressive swapping** (`vm.swappiness=100`) for the duration of the build, then remove it again.

```bash
sudo ./scripts/build-swap.sh on 3     # 3 GB swap file, swappiness 100
# … build zigbee2mqtt / Homebridge / plugins …
sudo ./scripts/build-swap.sh off      # remove it, restore the previous swappiness
```

[`build-swap.sh`](../scripts/build-swap.sh) also prints the current memory and swap state with `build-swap.sh status`.

Tips for the build itself:

- Build one thing at a time and stop other services first (`sudo systemctl stop homebridge zigbee2mqtt`).
- Give Node room for its heap: `export NODE_OPTIONS=--max-old-space-size=1024`.
- Limit parallel compile jobs: `export JOBS=1` (used by node-gyp) and `npm install --jobs=1`.
- It is slow — swapping on an SD card is measured in minutes, not seconds. Let it run.
