#!/usr/bin/env python3
"""Read the Rockchip image formats the Luckfox SDK produces — on any OS, with no dependencies.

    rkimage.py info FILE...          what a file is and what is inside
    rkimage.py extract update.img DIR  unpack the partitions packed into an update.img

Formats: RKFW (update.img), RKAF (the partition package inside it), LDR / BOOT (download.bin,
USB loader), RKNS (idblock.img, read by the chip's boot ROM), FIT (uboot.img / boot.img),
U-Boot environment (env.img) and ext4 / UBI (partition images). Read-only; nothing is changed.
Layouts follow the open-source rkdeveloptool, afptool and U-Boot (tools/rkcommon.c) sources.
"""
import hashlib
import struct
import sys
import zlib
from pathlib import Path


def rktime(b: bytes) -> str:
    year, month, day, hour, minute, second = struct.unpack("<HBBBBB", b[:7])
    return f"{year:04d}-{month:02d}-{day:02d} {hour:02d}:{minute:02d}:{second:02d}"


def chip(b: bytes) -> str:
    # stored little-endian as ASCII digits: b"6011" -> "RV1106" (RK chips start with 3)
    code = b[::-1].decode("ascii", "replace").strip("\0")
    return ("RK" if code.startswith("3") else "RV") + code if code.isdigit() else code


def human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024


def cstr(b: bytes) -> str:
    return b.split(b"\0", 1)[0].decode("ascii", "replace")


# ---------- LDR / BOOT: USB loader (download.bin), also embedded in update.img ----------

def ldr(data: bytes, base: int = 0) -> list:
    tag, size, version, merger = struct.unpack_from("<4sHII", data, base)
    when = rktime(data[base + 14:base + 21])
    c = chip(data[base + 21:base + 25])
    fields = struct.unpack_from("<BIBBIBBIBBB", data, base + 25)
    n471, off471, sz471, n472, off472, sz472, nldr, offldr, szldr, sign, rc4 = fields
    out = [f"Rockchip loader ({tag.decode().strip()}) — built {when} for {c}",
           f"  signed: {'yes' if sign == 0x53 else 'no'}, entries RC4-scrambled: {'no' if rc4 else 'yes'}"]
    for group, count, off, esz in (("471 (DDR init, run first)", n471, off471, sz471),
                                   ("472 (USB plug, talks to the flashing tool)", n472, off472, sz472),
                                   ("loader (written to the boot medium)", nldr, offldr, szldr)):
        for i in range(count):
            e = base + off + i * esz
            esize, etype = struct.unpack_from("<BI", data, e)
            name = data[e + 5:e + 45].decode("utf-16-le", "replace").split("\0", 1)[0]
            doff, dsize, delay = struct.unpack_from("<III", data, e + 45)
            out.append(f"  {group:44s} {name:20s} {human(dsize):>9s}  delay {delay} ms")
    return out


# ---------- RKNS: ID block v2 (idblock.img), what the boot ROM loads ----------

def rkns(data: bytes) -> list:
    size_and_n, boot_flag = struct.unpack_from("<II", data, 8)
    nimage = (size_and_n >> 16) & 0xFF
    hashes = {0: "none", 1: "SHA-256", 2: "SHA-512"}
    out = [f"Rockchip ID block v2 (RKNS) — {nimage} image(s), hash {hashes.get(boot_flag & 0xF, boot_flag)}"]
    names = ["DDR init (TPL)", "loader (SPL)", "image 3", "image 4"]
    for i in range(min(nimage, 4)):
        e = 120 + i * 88
        size_and_off, address = struct.unpack_from("<II", data, e)
        off_blocks, size_blocks = size_and_off & 0xFFFF, size_and_off >> 16
        out.append(f"  {names[i]:16s} at {off_blocks * 512:>7d} bytes, {human(size_blocks * 512):>9s}"
                   + (f", load address 0x{address:08x}" if address not in (0, 0xFFFFFFFF) else ""))
    return out


# ---------- RKFW / RKAF: update.img ----------

RKAF_PART = struct.Struct("<32s60sIIIII")


def rkaf_parts(data: bytes, base: int) -> list:
    magic, length = struct.unpack_from("<4sI", data, base)
    num = struct.unpack_from("<I", data, base + 8 + 0x22 + 0x1E + 0x38 + 8)[0]
    first = base + 8 + 0x22 + 0x1E + 0x38 + 12
    parts = []
    for i in range(min(num, 16)):
        name, filename, nand_size, pos, nand_addr, padded, size = RKAF_PART.unpack_from(data, first + i * RKAF_PART.size)
        parts.append({"name": cstr(name), "file": cstr(filename), "pos": pos, "size": size,
                      "nand_addr": nand_addr, "nand_size": nand_size})
    return parts


def rkaf(data: bytes, base: int = 0) -> list:
    model = cstr(data[base + 8:base + 8 + 0x22])
    maker = cstr(data[base + 8 + 0x22 + 0x1E:base + 8 + 0x22 + 0x1E + 0x38])
    out = [f"Rockchip partition package (RKAF) — model '{model or '-'}', manufacturer '{maker or '-'}'"]
    for p in rkaf_parts(data, base):
        out.append(f"  {p['name']:12s} {p['file']:28s} {human(p['size']):>9s}")
    return out


def rkfw(data: bytes, path: Path) -> list:
    hsize, version, merge = struct.unpack_from("<HII", data, 4)
    when, c = rktime(data[14:21]), chip(data[21:25])
    boot_off, boot_size, fw_off, fw_size = struct.unpack_from("<IIII", data, 25)
    total = path.stat().st_size
    trailer = total - (fw_off + fw_size)
    out = [f"Rockchip firmware (RKFW, update.img) — built {when} for {c}",
           f"  loader at {boot_off}, {human(boot_size)}; partition package at {fw_off}, {human(fw_size)}"
           + (f"; {trailer}-byte MD5 trailer" if trailer == 32 else "")]
    if trailer == 32:
        recorded = data[-32:].decode("ascii", "replace")
        actual = hashlib.md5(data[:-32]).hexdigest()
        out.append(f"  MD5 {recorded} — {'matches the content' if actual == recorded else 'DOES NOT MATCH (file damaged or modified)'}")
    out += ["", *ldr(data, boot_off), "", *rkaf(data, fw_off)]
    return out


# ---------- U-Boot environment and FIT ----------

def uboot_env(data: bytes) -> list:
    crc = struct.unpack_from("<I", data)[0]
    ok = zlib.crc32(data[4:]) & 0xFFFFFFFF == crc
    pairs = [p.decode("ascii", "replace") for p in data[4:].split(b"\0") if b"=" in p]
    return [f"U-Boot environment — CRC32 {'valid' if ok else 'INVALID'}, {len(pairs)} variable(s)"] + [f"  {p}" for p in pairs]


def fdt_nodes(data: bytes):
    """Yield (path, props) for every node of a flattened device tree (FIT images use this format)."""
    _, total, off_struct, off_strings = struct.unpack_from(">IIII", data)
    pos, path, props = off_struct, [], {}
    while pos < total:
        token = struct.unpack_from(">I", data, pos)[0]
        pos += 4
        if token == 1:      # begin node
            end = data.index(b"\0", pos)
            if path or props:
                yield "/".join(path), props
            path.append(data[pos:end].decode("ascii", "replace"))
            props = {}
            pos = (end + 4) & ~3
        elif token == 2:    # end node
            yield "/".join(path), props
            path.pop()
            props = {}
        elif token == 3:    # property
            length, name_off = struct.unpack_from(">II", data, pos)
            pos += 8
            name = data[off_strings + name_off:data.index(b"\0", off_strings + name_off)].decode()
            props[name] = data[pos:pos + length]
            pos = (pos + length + 3) & ~3
        elif token == 9:    # end
            break


def fit(data: bytes) -> list:
    out, seen = ["U-Boot FIT image (device-tree format)"], set()
    for path, props in fdt_nodes(data):
        parts = path.split("/")
        if len(parts) == 3 and parts[1] == "images" and path not in seen and props:
            seen.add(path)
            desc = cstr(props.get("description", b"")) or parts[2]
            kind = cstr(props.get("type", b""))
            size = props.get("data-size")
            size = struct.unpack(">I", size)[0] if size else len(props.get("data", b""))
            out.append(f"  {parts[2]:12s} {kind:10s} {human(size):>9s}  {desc}")
    return out


# ---------- dispatch ----------

def info(path: Path) -> list:
    with path.open("rb") as f:
        head = f.read(4096)
    magic = head[:4]
    if magic == b"RKFW":
        return rkfw(path.read_bytes(), path)
    if magic in (b"LDR ", b"BOOT"):
        return ldr(path.read_bytes())
    if magic == b"RKNS":
        return rkns(head)
    if magic == b"RKAF":
        return rkaf(path.read_bytes())
    if magic == b"\xd0\x0d\xfe\xed":
        size = struct.unpack_from(">I", head, 4)[0]
        with path.open("rb") as f:
            return fit(f.read(max(size, 4096)))
    if b"=" in head[4:64] and head[4:5].isalpha():
        return uboot_env(path.read_bytes())
    if len(head) >= 0x43A and head[0x438:0x43A] == b"\x53\xef":
        return ["ext4 / ext2 filesystem — read with debugfs (e2fsprogs) or mount on Linux"]
    if magic == b"UBI#":
        return ["UBI image (raw NAND flash) — read with ubi_reader"]
    return [f"unknown format (starts with {magic.hex()})"]


def extract(path: Path, target: Path) -> None:
    data = path.read_bytes()
    if data[:4] != b"RKFW":
        sys.exit("extract works on update.img (RKFW) files")
    fw_off = struct.unpack_from("<I", data, 33)[0]
    target.mkdir(parents=True, exist_ok=True)
    for p in rkaf_parts(data, fw_off):
        if not p["size"]:
            continue
        name = Path(p["file"]).name or p["name"]
        (target / name).write_bytes(data[fw_off + p["pos"]:fw_off + p["pos"] + p["size"]])
        print(f"  {name:28s} {human(p['size']):>9s}")
    boot_off, boot_size = struct.unpack_from("<II", data, 25)
    (target / "loader.bin").write_bytes(data[boot_off:boot_off + boot_size])
    print(f"  {'loader.bin':28s} {human(boot_size):>9s}")


def main() -> None:
    if len(sys.argv) < 3 or sys.argv[1] not in ("info", "extract"):
        sys.exit(__doc__)
    if sys.argv[1] == "extract":
        extract(Path(sys.argv[2]), Path(sys.argv[3] if len(sys.argv) > 3 else "extracted"))
        return
    for name in sys.argv[2:]:
        print(f"== {name}")
        print("\n".join(info(Path(name))))
        print()


if __name__ == "__main__":
    main()
