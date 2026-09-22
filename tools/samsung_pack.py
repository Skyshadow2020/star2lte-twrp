#!/usr/bin/env python3
"""samsung_pack.py — assemble a Samsung (Exynos 9810) boot/recovery image.

Samsung header v0 quirks (verified against the device's own images):
  - page size 2048
  - dt_size/dt_addr occupy the standard v0 "unused" fields (offsets 40/44)
  - the DTBH blob is appended page-aligned AFTER the ramdisk
  - dt_addr holds a Samsung magic (0x20040134 on this device) — copied verbatim

Recovery-boot quirks (each one caused a real failure — do not remove):
  - TRIM: the TWRP 12.1 ramdisk cpio carries trailing bytes AFTER its
    TRAILER!!! entry; the kernel's initramfs parser rejects the whole
    archive ('junk in compressed archive' -> bootloop). Truncate exactly at
    the trailer end before re-compressing.
  - RAMDISK_PAD: the SBL passes the recovery initrd with size - 8 (it
    reserves the last 8 bytes of the region for its boot-command buffer).
    Appending 8 pad bytes means SBL's size-8 still covers the complete gzip
    stream. The pad is written AFTER the gzip stream and counted in the
    header's ramdisk_size.
  - The gzip magic check is b'\\x1f\\x8b' — a previous edit mangled it to
    b'\\x1f\\xc2\\x8b' (UTF-8 mojibake) which silently disabled the TRIM.

Usage:
  samsung_pack.py <template-header-img> <kernel-Image> <ramdisk-gz> <dtbh> <out.img>

Exits non-zero if the assembled image exceeds RECOVERY_MAX_BYTES (the
star2lte RECOVERY partition is 68,149,248) — better to fail the CI job than
produce an image that truncates on dd.
"""
import struct
import sys

PAGE = 2048
RECOVERY_MAX_BYTES = 68149248  # star2lte RECOVERY partition size


def align(n, p=PAGE):
    return (n + p - 1) // p * p


def trim_cpio_trailer(gz_bytes):
    """Decompress, cut the cpio exactly at TRAILER!!! end, recompress."""
    import gzip as _gz
    cpio = _gz.decompress(gz_bytes)
    pos = 0
    cut = None
    while pos + 110 < len(cpio):
        if cpio[pos:pos + 6] != b"070701":
            cut = pos
            break
        nsz = int(cpio[pos + 94:pos + 102], 16)
        fsz = int(cpio[pos + 54:pos + 62], 16)
        name = cpio[pos + 110:pos + 110 + nsz - 1]
        nxt = pos + 110 + nsz
        nxt = (nxt + 3) & ~3
        nxt += fsz
        nxt = (nxt + 3) & ~3
        if name == b"TRAILER!!!":
            cut = nxt
            break
        pos = nxt
    if cut:
        print(f"  TRIM: cpio {len(cpio)} -> {cut} (trailing junk removed)")
        return _gz.compress(cpio[:cut], 6)
    print("  TRIM: no trailing junk found")
    return gz_bytes


def main():
    if len(sys.argv) != 6:
        print(__doc__)
        return 2
    template, kernel_path, ramdisk_path, dt_path, out_path = sys.argv[1:6]

    hdr = bytearray(open(template, "rb").read(align(1)))

    kernel = open(kernel_path, "rb").read()
    ramdisk = open(ramdisk_path, "rb").read()
    dt = open(dt_path, "rb").read()

    # TRIM: cut the cpio trailer junk (see docstring) — only for gzip input
    if ramdisk[:2] == b"\x1f\x8b":
        ramdisk = trim_cpio_trailer(ramdisk)
    else:
        print("  TRIM: input is not gzip, left untouched")

    # RAMDISK_PAD: SBL reserves the last 8 bytes of the passed initrd
    ramdisk += b"\x00" * 8

    struct.pack_into("<I", hdr, 8, len(kernel))
    struct.pack_into("<I", hdr, 16, len(ramdisk))

    out = bytearray(hdr)
    out += kernel
    out += b"\x00" * (align(len(kernel)) - len(kernel))
    out += ramdisk
    out += b"\x00" * (align(len(ramdisk)) - len(ramdisk))
    out += dt

    if len(out) > RECOVERY_MAX_BYTES:
        print(
            f"ERROR: assembled image is {len(out)} bytes but the RECOVERY "
            f"partition holds {RECOVERY_MAX_BYTES} — it would truncate on dd. "
            "Slim the ramdisk (trustlets/blobs) and retry.",
            file=sys.stderr,
        )
        return 1

    open(out_path, "wb").write(out)
    print(
        f"samsung_pack: kernel={len(kernel)} ramdisk={len(ramdisk)} "
        f"dt={len(dt)} -> {out_path} ({len(out)} bytes, "
        f"{RECOVERY_MAX_BYTES - len(out)} under the partition limit)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
