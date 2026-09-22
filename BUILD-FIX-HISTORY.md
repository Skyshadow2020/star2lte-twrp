# BUILD-FIX-HISTORY — from first failed run to the first green build

Every TWRP-12.1-for-star2lte build run on GitHub Actions, what failed, and the
exact fix. Chronological. The chain took ~30 runs across two accounts
(Skyshadow2022 + Skyshadow2020, repos public since run 18).

Legend: ❌ failed · 🟢 GREEN (artifact produced)

## Phase 0 — tooling decisions

| Run | What happened | Fix / decision |
|---|---|---|
| 35591045724 ❌ | twrpdtgen: `ro.product.board` missing in the old TWRP ramdisk | abandon twrpdtgen → handwritten device tree |
| (analysis) | the "newest" official TWRP (star2qltechn 3.7.0) unpacked: Snapdragon + keymaster@3.0-only + zero FBE glue | rejected as base — wrong SoC, can never decrypt our Exynos/Trustonic data |

## Phase 1 — build system alignment

| Run | What happened | Fix / decision |
|---|---|---|
| 35593372861 ❌ | `twrp-12.1` branch not in omni manifest repo (stops at 9.0) | `platform_manifest_twrp_aosp` + target renamed `twrp_star2lte` |
| 35594478139 ❌ | runner VM died mid-sync (no logs — private runners: 2-core/7GB) | first sight of infra limits |
| 35596798701 ❌ | died again, same signature | retry |
| 35599661764 ❌ | `./setup-tree.sh` exit 126 | `git update-index --chmod=+x` |

## Phase 2 — device tree / AOSP 12.1 alignment

| Run | What happened | Fix / decision |
|---|---|---|
| 35600644623 ❌ | `embedded.mk does not exist` (removed in AOSP 12) | inherit `aosp_base.mk` — official a52q TWRP-12.1 pattern |
| 35602741788 ❌ | `Unknown ARM architecture version: armv8` | `TARGET_ARCH_VARIANT := armv8-a`, real CPU variants |
| 35604243231 ❌ | `Incorrect TARGET_2ND_ARCH_VARIANT, armv8-a` | `armv8-2a` |

## Phase 3 — runner resources (disk / RAM / swap)

| Run | What happened | Fix / decision |
|---|---|---|
| 35606064525 ❌ | soong bootstrap SIGTERM at 99% (7GB RAM OOM) | swap — but placed BEFORE sync at first |
| 35616680319 ❌ | 10G swapfile ate the 14G-class disk → ENOSPC in sync | swap MOVED after sync, sized down |
| 35618336751 ❌ | `fallocate: Text file busy` — image ships a /swapfile | `swapoff -a` + recreate |
| 35619722846 ❌→⚠️ | sync OK, build to 99%, then silent death | deeper disk diet needed |
| 35623635404 ❌ | remove-project of already-removed projects | `optional="true"` on all removes |
| (public flip) | repos made PUBLIC → 4-core / 16GB / ~84GB runners, reliable infra | solved the OOM + infra-death class entirely |

## Phase 4 — AOSP mainline coupling (each = one removed project too many)

| Run | What happened | Fix / decision |
|---|---|---|
| 35624200641 ❌ | frameworks/base apex api txt files missing | keep `packages/modules` |
| 35629974228 ❌ | `platform-bootclasspath` needs dex jars | restore art/libcore/packages-providers |
| 35632089901 ❌ | `art.module.public.api` missing tracking files | restore `prebuilts/sdk` |
| 35638295709 ❌ (acct2) | same, parallel account | synced |
| 35696343228 ❌ | `keystore2 missing dependencies: libstd` | restore `prebuilts/rust` |

## Phase 5 — the final mile

| Run | What happened | Fix / decision |
|---|---|---|
| 35657819225/35657823241 ❌ | rsync: `could not make way for new symlink: root/vendor` at 99% | diagnosed with an in-band diagnostic step: `root/vendor` was a SYMLINK (→/system/vendor) colliding with health@2.1/sepolicy recovery modules — **root cause: missing `BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs`** (no separate vendor partition declared). With it, root/vendor is a mount-point dir and rsync merges. Blobs moved to `recovery/root/system/vendor/`. |
| 35660612193/35660615845 ❌ | recovery.img too large: 71.5MB > 68.1MB partition | user spotted the `[arm]` double-compile → drop `TARGET_2ND_ARCH` (recovery is 64-bit only) |
| 35703050903/35703054451 ❌ | still too large: 69.6MB | verified-against-source diet: `TW_EXCLUDE_BASH/NANO/LPTOOLS/MTP/TZDATA/LPDUMP/APEX`, `TW_INCLUDE_NTFS_3G := false` (TWRPAPP/SNAP flags don't exist in 12.1) |
| 35707711259 ❌ | `libopenaes` missing after `TW_EXCLUDE_ENCRYPTED_BACKUPS` — recovery links it unconditionally | flag reverted |
| 35710366409/35710370945 ❌ | **mka SUCCEEDED (`build completed successfully, 32:06`)** — but the Diagnose debug step (empty grep → exit 1) killed the job before Repack/Upload | Diagnose step removed |
| **35716430059 🟢** | **GREEN** — recovery-samsung.img 66.7MB (slim tune-branch kernel 31.4MB + ramdisk + DTBH, 1.4MB headroom), artifact uploaded | **first successful build** |

## Phase 6 — flash attempt (open)

| What happened | State |
|---|---|
| flashed `recovery-samsung.img` → **recovery bootloop** | OPEN — prime suspect: DTBH from the susfs-branch build paired with the slim tune-branch kernel (possible DTS mismatch), or the HAL-glue rc seclabels. Old omni TWRP 3.7.0 restored (sha `d1ede449…`), backups of both kept |
| `recovery.img` (the AOSP-format artifact, NO DTBH) | never flash — boots nothing on Samsung Exynos |

## Standing conclusions

1. The proven recipe: minimal-manifest-twrp_aosp `twrp-12.1` + handwritten tree
   (`aosp_base` inherit) + full-enough manifest (do NOT remove
   packages/modules, art, libcore, packages/providers, prebuilts/sdk,
   prebuilts/rust) + swap after sync + public runners.
2. `BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE` must be declared on legacy
   system-as-root Exynos devices or the recovery ramdisk assembly breaks.
3. Samsung recovery images need the DTBH appended (header v0, dt fields) —
   the AOSP-format `recovery.img` is unbootable.
4. Decrypt stack compiled in: keystore2, keymaster3 HAL, Trustonic
   mcDriverDaemon + registry trustlets, gatekeeper — all present in the
   green build's ramdisk.

## Phase 6 addendum — the rescue (2026-09-22)

The bootloop could not be caught by adb (kernel dies before adbd), so:
entered **Download Mode** (Vol- + Bixby + Power, cable, Vol+), flashed
`recovery-twrp-old.tar.md5` (odin tar of the working omni 3.7.0) via **Odin AP
slot** — phone restored, system healthy.

Backups inventory:
- `backup/recovery-twrp-3.7.0-omni.img` — the working TWRP (sha d1ede449…)
- `backup/web-twrp-current.img` — same, pulled after rescue
- Desktop `recovery-twrp-old.tar.md5` — Odin-flashable copy
- `builds/twrp-35716430059/recovery-samsung.img` — the decrypt-capable build
  that bootloops (DO NOT re-flash until phase-6 diagnosis completes)

Next-session plan (2 items):
1. pack the slim kernel's OWN `dtb` (from its CI zip, `tmp-slim/dtb` — byte-
   identical DTBH confirmed between branches, so mismatch is less likely than
   thought) — rebuild samsung_pack with the matching DTBH anyway, retest.
2. test-build WITHOUT the HAL-glue rc files (seclabel u:r:recovery:s0 is the
   second suspect) — bisect the ramdisk additions if needed.

## Phase 6 continued — bootloop root cause FOUND (2026-09-22)

`/proc/last_kmsg` after the loop: THREE distinct panics, each fixed in turn:
1. `gpu_dvfs_get_step` NULL deref — recovery-DT strips the GPU node → dvfs
   NULL → kernel guard added (graceful 0).
2. `s2mpb02_led_probe` strlen(NULL) — recovery-DT strips the LED label →
   skip-unnamed-LEDs guard added.
3. **`VFS: Unable to mount root fs` + `junk in compressed archive`** — THE
   final one: the SBL passes the recovery initrd with **size − 8** (it
   reserves the last 8 bytes of the recovery ramdisk for the boot-command
   buffer; the system boot's ATAG is exact — measured: ours 0x215AAB9 →
   ATAG 0x215AAB1). The missing 8 bytes = the gzip CRC footer → gunzip CRC
   fail → initramfs rejected → panic loop (23× R reboots in param logs).
   **Fix: pad the gzipped ramdisk with 8 bytes** — the reserved 8 now eat
   padding and the kernel receives the complete stream (verified: the
   size−8 window decompresses fully with eof=True). Fix is permanent in
   `tools/samsung_pack.py` (RAMDISK_PAD).
