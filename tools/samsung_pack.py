#!/usr/bin/env python3
"""samsung_pack.py — assemble a Samsung (Exynos 9810) boot/recovery image.

Samsung header v0 quirks (verified against the device's own images):
  - page size 2048
  - dt_size/dt_addr occupy the standard v0 "unused" fields (offsets 40/44)
  - the DTBH blob is appended page-aligned AFTER the ramdisk
  - dt_addr holds a Samsung magic (0x20040134 on this device) — copied verbatim

Usage:
  samsung_pack.py <template-header-img> <kernel-Image> <ramdisk-gz> <dtbh> <out.img>

The template provides every header field verbatim (addrs, cmdline, magic);
only kernel_size and ramdisk_size are patched to the new parts.
"""
import struct
import sys

PAGE = 2048


def align(n, p=PAGE):
    return (n + p - 1) // p * p


def main():
    template, kernel_path, ramdisk_path, dt_path, out_path = sys.argv[1:6]

    hdr = bytearray(open(template, "rb").read(align(1)))  # first page
    base = struct.unpack("<I", hdr[12 + 16:16 + 16])[0]  # not used directly

    kernel = open(kernel_path, "rb").read()
    ramdisk = open(ramdisk_path, "rb").read()
    dt = open(dt_path, "rb").read()

    struct.pack_into("<I", hdr, 8, len(kernel))
    struct.pack_into("<I", hdr, 16, len(ramdisk))

    out = bytearray(hdr)
    out += kernel
    out += b"\x00" * (align(len(kernel)) - len(kernel))
    out += ramdisk
    out += b"\x00" * (align(len(ramdisk)) - len(ramdisk))
    out += dt

    open(out_path, "wb").write(out)
    print(f"samsung_pack: kernel={len(kernel)} ramdisk={len(ramdisk)} dt={len(dt)} -> {out_path} ({len(out)} bytes)")


if __name__ == "__main__":
    main()
