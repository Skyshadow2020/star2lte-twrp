# star2lte-twrp — TWRP with FBE decrypt, built on GitHub Actions

Goal: a recovery for the Galaxy S9+ Exynos (**star2lte**, SM-G965F) that
**decrypts /data** of the PE13 (Android 13, FBE) ROM — unlike the shipped
omni TWRP which leaves data locked (`Required key not available`).

## Where the project is now (2026-09-22)

- Pipeline validated step-by-step; failures 17–20 were tree-diet/rust/sdk/symlink
  issues, each fixed. Run #21 is the first full-pipeline validation build.
- **HAL launch glue landed (d04f023 + b335a5b)** — the piece run #21 will not
  have: the recovery ramdisk previously carried the keymaster3/gatekeeper/
  Trustonic blobs but NOTHING started them (no .rc existed anywhere), and
  `mcDriverDaemon` was missing its trustlets.
  - `init.recovery.samsungexynos9810.rc` + `init.recovery.star2lte.rc` (both
    ro.hardware names covered): mirrors the ROM's mobicore/keymaster3/
    gatekeeper rc — mobicore starts at fs, keymaster3+gatekeeper at late-fs,
    BEFORE TWRP's Decrypt Data flow.
  - `vendor-blobs/app/mcRegistry/` — all 30 Trustonic trustlet binaries
    (22 MB) pulled from the phone; `mcDriverDaemon` loads them with its `-r`
    args (paths remapped to /system/vendor/app/mcRegistry).
  - Services run as root with `seclabel u:r:recovery:s0` and
    `LD_LIBRARY_PATH=/system/vendor/lib64` (recovery linker namespaces don't
    search vendor paths; the ROM's `user nobody` would lose /dev/mobicore).
- The prebuilt kernel is our own 4.9.337 audio-fix lineage (ROM-era fscrypt +
  Trustonic drivers builtin) — the codec race fix landed in it on 09-21.

## Run it

Actions → **TWRP star2lte build** → Run workflow (the NEXT run after #21
carries the HAL glue). First build ≈ 1.5–2 h. Flash `recovery-samsung.img` to
RECOVERY, boot, test Decrypt Data.

## Decrypt test matrix / iteration knobs

1. No PIN → should decrypt automatically; with PIN → enter it.
2. `fscrypt_policy` input: `2` (A13 default) then `1` (currently set).
3. If keymaster service fails to start: check `dmesg | grep audio-dbg`, the
   service stderr in the TWRP console, and missing-library names — add the
   missing .so to vendor-blobs/lib64.
4. If keymaster starts but key ops fail: vendor sepolicy patches for the
   recovery domain, or `TW_CRYPTO_USE_SYSTEM_VOLD`.

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
