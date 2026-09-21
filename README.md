# star2lte-twrp — TWRP with FBE decrypt for Galaxy S9+ Exynos, built on GitHub Actions

Target: **star2lte** (SM-G965F, Exynos 9810) running **PE13** (Android 13, FBE).
Goal: a recovery whose **Decrypt Data actually works** — the shipped omni TWRP
leaves /data locked (`Required key not available`) because it has no keymaster
integration at all.

Repo is **public** since 2026-09-21 → standard runners upgraded to 4-core /
16GB / ~84GB disk (private runners were 2-core / 7GB and died repeatedly:
4× "lost communication" / ENOSPC deaths before going public).

## Device tree (handwritten — twrpdtgen cannot identify the old TWRP)

- `device/samsung/star2lte/` — BoardConfig (`exynos9810`, armv8-a arch
  variants, boot header v0), `twrp_star2lte.mk`
  (embedded → **aosp_base** inherit, official TWRP 12.1 pattern), fstab
  mirrored from the ROM's own `/vendor/etc/fstab`
  (`fileencryption=aes-256-xts` → **v1 policies**, `TW_USE_FSCRYPT_POLICY := 1`).
- `prebuilt/Image` + `prebuilt/dt` — **our own kernel** (kernel-s9plus-hdmi,
  susfs-v2-experiment line): ROM-era fscrypt + Trustonic drivers, plus the
  audio boot-race recovery fix.
- `vendor-blobs/` — Samsung keymaster3 + phh skeymaster shims + Trustonic
  (`libMcClient`, `mcDriverDaemon`) + gatekeeper, pulled from the phone's
  `/vendor` with root. Packed into the ramdisk at `system/vendor/` (NOT
  `vendor/` — the build creates root/vendor as a symlink and a real dir there
  breaks the final rsync).
- `tools/samsung_pack.py` — re-packs the built recovery into the Samsung
  header-v0 + DTBH format (dt_size/dt_addr quirks, page 2048), using the
  original TWRP image header as template.

## Build-fix chain (one error at a time, all verified)

| # | Failure | Fix |
|---|---|---|
| 1 | manifest `twrp-12.1` not in omni repo | use `platform_manifest_twrp_aosp` |
| 2 | twrpdtgen: no `ro.product.board` in old ramdisk | handwritten tree |
| 3 | sanity wanted HDMI files | dropped with the HDMI workstream |
| 4 | `embedded.mk` gone in AOSP 12.1 | `aosp_base.mk` (a52q pattern) |
| 5 | `Unknown ARM architecture version: armv8` | `armv8-a` + real CPU variants |
| 6 | `TARGET_2ND_ARCH_VARIANT armv8-a` rejected | `armv8-2a` |
| 7 | runner disk 73G: sync+build ENOSPC ×3 | slimhub-style cleanup + remove-heavy local manifest (154→88 projects) |
| 8 | runner RAM 7G: soong bootstrap OOM at 99% | 6–8G swap **after** sync (before = ENOSPC again) |
| 9 | `frameworks/base` apex api files missing | keep `packages/modules` |
| 10 | `platform-bootclasspath` needs dex jars | restore art/libcore/packages-providers |
| 11 | `art.module.public.api` missing tracking files | restore `prebuilts/sdk` |
| 12 | `keystore2 missing dependencies: libstd` | restore `prebuilts/rust` |
| 13 | rsync: `could not make way for new symlink: root/vendor` | blobs to `recovery/root/system/vendor` |

## Status

- Builds #20–22 reached **99% / full ninja compile** (keystore2 included —
  that IS the FBE decrypt stack).
- Latest runs (vendor-path fix): account1 run 35660612193, account2 run
  35660615845 (parallel builds on two accounts, both public repos).
- Next: flash `recovery-samsung.img` to RECOVERY (backup exists:
  `backup/recovery-twrp-3.7.0-omni.img`), boot, test Decrypt Data.

## Run it

Actions → **TWRP star2lte build** → Run workflow (on either account).
