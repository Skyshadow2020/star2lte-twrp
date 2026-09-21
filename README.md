# star2lte-twrp — TWRP with FBE decrypt, built on GitHub Actions

Goal: a recovery for the Galaxy S9+ Exynos (**star2lte**, SM-G965F) that
**decrypts /data** of the PE13 (Android 13, FBE) ROM — unlike the shipped
omni TWRP which leaves data locked (`Required key not available`).

## Why the shipped TWRP cannot decrypt

Analyzed `twrp-3.7.0_9-0-star2qltechn.img` (the newest official TWRP, but for
the **Snapdragon** variant): kernel `4.9.65-klabit87`, keymaster **@3.0 only**,
zero cryptfsvold/volddecrypt/libfscrypt, `fstab.qcom` (qcom). The phone is
Exynos with a **Trustonic** TEE. Decryption is compile-time (keymaster HAL
version + TEE transport + fscrypt glue), not something that can be patched
into a ramdisk afterwards.

## What this repo does

- `star2lte-twrp-base.img` — our current omni TWRP for star2lte (decryption
  unsupported); used only as the **device-tree source** via twrpdtgen on the
  Linux runner.
- `vendor-blobs/` — Samsung keymaster3 + phh shims + Trustonic
  (`libMcClient`, `mcDriverDaemon`) + gatekeeper HALs pulled from the phone's
  `/vendor` with root. These get packed into the recovery ramdisk so TWRP's
  crypto glue can talk to the same TEE the ROM uses.
- `.github/workflows/build-twrp.yml` — full pipeline: deps → twrpdtgen →
  sync omni twrp-12.1 (depth 1) → setup-tree.sh (blobs + `TW_INCLUDE_FBE`,
  `TW_USE_FSCRYPT_POLICY`) → `mka recoveryimage` → artifact.

## Run it

Actions → **TWRP star2lte build** → Run workflow. First build ≈ 1.5–2 h.
Flash the artifact `recovery.img` and test Decrypt Data (no PIN set → it
should decrypt automatically; with a PIN, enter it).

## Iteration knobs

- `fscrypt_policy` input: try `2` (A13 default), then `1`.
- If decrypt still fails, next steps: vendor sepolicy patches for the
  recovery domain, `TW_CRYPTO_USE_SYSTEM_VOLD`, or swapping the keymaster
  service binaries into `recovery/root/vendor/bin/hw/` init flow.
