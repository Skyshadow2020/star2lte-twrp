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

# HAL launch glue rc files ALSO at the RAMDISK ROOT: TWRP 12.1's init.rc
# imports /init.recovery.*.rc from the root — without these the keymaster/
# gatekeeper/mobicore services never start and decrypt hangs the UI
cp -a "$DT/recovery/root/system/etc/init/hw/init.recovery.samsungexynos9810.rc" "$DT/recovery/root/"
cp -a "$DT/recovery/root/system/etc/init/hw/init.recovery.star2lte.rc"        "$DT/recovery/root/"


# Trustonic trustlets — mcDriverDaemon loads these (keymaster3 TEE transport)
mkdir -p "$DT/recovery/root/system/vendor/app/mcRegistry"
cp -a vendor-blobs/app/mcRegistry/*   "$DT/recovery/root/system/vendor/app/mcRegistry/"

# the HAL init rc comes from the device tree (recovery/root/system/etc/init/hw/)
# init imports it by ro.hardware=samsungexynos9810 — nothing to copy here

echo "--- tree ready ---"
ls "$DT"
