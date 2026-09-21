#!/usr/bin/env bash
# setup-tree.sh — place the committed device tree into the omni build tree and
# pack the Samsung keymaster3/phh/Trustonic blobs into the recovery ramdisk.
set -euo pipefail

DT=twrp/device/samsung/star2lte
rm -rf "$DT"
mkdir -p twrp/device/samsung
cp -r device/samsung/star2lte "$DT"

# vendor blobs -> recovery ramdisk, under system/vendor: the build assembles
# root/vendor as a SYMLINK and a real dir at recovery/root/vendor breaks the
# final rsync ("could not make way for new symlink: root/vendor").
mkdir -p "$DT/recovery/root/system/vendor/lib64/hw" "$DT/recovery/root/system/vendor/bin/hw"
cp -a vendor-blobs/lib64/*.so         "$DT/recovery/root/system/vendor/lib64/"
cp -a vendor-blobs/lib64/hw/*.so      "$DT/recovery/root/system/vendor/lib64/hw/"
cp -a vendor-blobs/bin/hw/*           "$DT/recovery/root/system/vendor/bin/hw/"
cp -a vendor-blobs/bin/mcDriverDaemon "$DT/recovery/root/system/vendor/bin/"
chmod 750 "$DT/recovery/root/system/vendor/bin/mcDriverDaemon"

echo "--- tree ready ---"
ls "$DT"
