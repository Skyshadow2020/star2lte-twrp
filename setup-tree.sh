#!/usr/bin/env bash
# setup-tree.sh — place the twrpdtgen-generated tree into the omni build,
# pack the Samsung keymaster3/Trustonic blobs into the recovery ramdisk, and
# append the FBE-decrypt flags. Run on the CI runner.
set -euo pipefail

TREE="${1:?usage: setup-tree.sh <generated-tree-path> [fscrypt-policy]}"
POLICY="${2:-2}"

[ -d "$TREE" ] || { echo "tree not found: $TREE"; exit 1; }

DT=twrp/device/samsung/star2lte
rm -rf "$DT"
mkdir -p twrp/device/samsung
cp -r "$TREE" "$DT"
echo "tree placed: $DT"

# --- vendor blobs into the recovery ramdisk ---
mkdir -p "$DT/recovery/root/vendor/lib64/hw" "$DT/recovery/root/vendor/bin/hw"
cp -a vendor-blobs/lib64/*.so        "$DT/recovery/root/vendor/lib64/"
cp -a vendor-blobs/lib64/hw/*.so     "$DT/recovery/root/vendor/lib64/hw/"
cp -a vendor-blobs/bin/hw/*          "$DT/recovery/root/vendor/bin/hw/"
cp -a vendor-blobs/bin/mcDriverDaemon "$DT/recovery/root/vendor/bin/"
chmod 750 "$DT/recovery/root/vendor/bin/mcDriverDaemon"

# --- FBE decrypt flags ---
cat >> "$DT/BoardConfig.mk" <<EOF

# crypto / FBE decrypt (added by CI setup-tree.sh)
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_FBE := true
TW_USE_FSCRYPT_POLICY := $POLICY
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_CRYPTO_SYSTEM_VOLD_DEBUG := true
EOF

echo "--- tree ready ---"
ls "$DT"
