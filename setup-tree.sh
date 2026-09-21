#!/usr/bin/env bash
# setup-tree.sh — place the committed device tree into the omni build tree and
# pack the Samsung keymaster3/phh/Trustonic blobs into the recovery ramdisk.
set -euo pipefail

DT=twrp/device/samsung/star2lte
rm -rf "$DT"
mkdir -p twrp/device/samsung
cp -r device/samsung/star2lte "$DT"

# vendor blobs -> recovery ramdisk
mkdir -p "$DT/recovery/root/vendor/lib64/hw" "$DT/recovery/root/vendor/bin/hw"
cp -a vendor-blobs/lib64/*.so         "$DT/recovery/root/vendor/lib64/"
cp -a vendor-blobs/lib64/hw/*.so      "$DT/recovery/root/vendor/lib64/hw/"
cp -a vendor-blobs/bin/hw/*           "$DT/recovery/root/vendor/bin/hw/"
cp -a vendor-blobs/bin/mcDriverDaemon "$DT/recovery/root/vendor/bin/"
chmod 750 "$DT/recovery/root/vendor/bin/mcDriverDaemon"

echo "--- tree ready ---"
ls "$DT"
