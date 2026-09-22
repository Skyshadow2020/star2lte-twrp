# HANDOFF — TWRP 12.1 decrypt for star2lte: continue from home (Linux)

Date: 2026-09-22/23 · Author session: ZCode on the Windows ProDesk box
Repos (BOTH accounts, keep synced):
- **Skyshadow2022/star2lte-twrp** (public, primary)
- **Skyshadow2020/star2lte-twrp** (public, parallel mirror — second Actions quota)
- Kernel: **Skyshadow2022/kernel-s9plus-hdmi** (public), branch `tune-2026-09-12`
  (slim recovery-kernel line) and `susfs-v2-experiment` (daily-driver line)
- Module/tooling: **Skyshadow2022/star2lte-tune** (private), mirrored on 2020

## Mission

A TWRP 12.1 recovery for star2lte (Galaxy S9+ Exynos SM-G965F) on the PE13 ROM
(Android 13, FBE `fileencryption=aes-256-xts`, v1 policies) whose **Decrypt
Data actually works**. The stock omni TWRP 3.7.0 cannot decrypt (no keymaster
integration at all). Everything compiles; the last unknown is the bootloop.

## Where the build stands (exact)

- The full AOSP-12.1 recovery build **completes** (`build completed
  successfully, 32:06` — run 35710366409).
- Green artifacts exist: run **35716430059** (acct 2) and later guarded
  rebuilds **35759417166** / **35770915184** / **35790361983** (acct 1) and
  **35716430059→35790366872** (acct 2).
- Artifact contents: `recovery-samsung.img` (Samsung header v0 + DTBH, use
  this one) and `recovery.img` (AOSP format — **unbootable on Samsung, never
  flash**).
- The recovery kernel = slim `tune-2026-09-12` CI build (31.4MB Image, audio
  race fix included, no instrumentation) + DTBH from the susfs build (byte-
  identical between branches — verified).
- Ramdisk carries the FBE decrypt stack: keystore2, Samsung keymaster3 HAL
  impl + phh skeymaster shims, Trustonic `libMcClient` + `mcDriverDaemon` +
  registry trustlets, gatekeeper — all pulled from the phone's /vendor
  (`vendor-blobs/`), installed under `recovery/root/system/vendor/` (NOT
  `recovery/root/vendor/` — that path is a build-created symlink).
- HAL launch glue (init.recovery.*.rc, services with
  `LD_LIBRARY_PATH=/system/vendor/lib64`) landed from the parallel session.

## The bootloop saga — 3 kernel panics, all root-caused from /proc/last_kmsg

The SBL, in RECOVERY boots, passes a MINIMAL device tree (properties stripped:
LED labels, torch params, touch GPIOs, NFC IRQ...). System boots see the full
DT — that's why the same kernel boots system fine. Every vendor driver that
assumes a property exists = potential panic. Found and fixed so far:

1. **`gpu_dvfs_get_step` NULL deref** (`gpex_dvfs_external.c`) — GPU node
   stripped → `dvfs` NULL → cooling initcall derefs. Fix: guard, return 0;
   cooling init bails with -EINVAL gracefully. ✅ verified fixed (panic moved)
2. **`s2mpb02_led_probe` strlen(NULL)** (`leds-s2mpb02.c`) — `temp_str` is
   UNINITIALIZED on `of_property_read_string` failure (garbage pointer, NOT
   NULL — a plain NULL guard misses it!). Fix v2: bail the whole LED probe
   with -ENODEV when id/ledname are missing or the index is out of range
   (torch LED is cosmetic in recovery). ✅ committed, CI 35786184631 GREEN
3. **`VFS: Unable to mount root fs` + `junk in compressed archive`** — the
   SBL passes the recovery initrd with **size − 8** (it reserves the last 8
   bytes of the recovery ramdisk for its boot-command buffer; measured: our
   ramdisk 0x215AAB9 → ATAG 0x215AAB1; the system boot's ATAG is exact).
   Missing 8 bytes = gzip CRC footer cut → gunzip CRC fail → initramfs
   rejected → panic loop (23× R reboots in param logs). Fix: **pad the
   gzipped ramdisk with 8 bytes** (`RAMDISK_PAD` in `tools/samsung_pack.py`)
   — the reserved 8 then eat padding and the kernel receives the complete
   stream. Verified arithmetically (size−8 window decompresses fully,
   eof=True). ✅ in the latest builds

## CURRENT STATE — what to do from home

1. Check the latest runs:
   - acct1: https://github.com/Skyshadow2022/star2lte-twrp/actions/runs/35790361983
   - acct2: https://github.com/Skyshadow2020/star2lte-twrp/actions/runs/35790366872
   These have ALL fixes (GPU guard + LED bail + RAMDISK_PAD + slim kernel).
2. When green: download the artifact → `recovery-samsung.img` → Odin tar:
   ```bash
   cp recovery-samsung.img /tmp/recovery.img && cd /tmp
   tar -H ustar -cf recovery.tar recovery.img
   cp recovery.tar recovery.tar.md5 && md5sum -t recovery.tar.md5 >> recovery.tar.md5
   ```
3. Flash via **Odin, AP slot only** (Download Mode: Vol- + Bixby + Power,
   cable, Vol+). RECOVERY partition only — boot/data untouched.
4. **The test**: if TWRP 12.1 boots (no loop) → adb → check decrypt:
   ```bash
   adb shell 'ls /data/media/0; cat /tmp/recovery.log | grep -i -e decrypt -e keymaster'
   ```
   Decrypted = /data/media/0 shows real files. Then the mission is DONE and
   the kernel-side panic chain is fully closed.
5. **If it bootloops AGAIN**: it's panic #4 from a yet-unstripped-driver.
   The iteration loop is fast and proven:
   ```bash
   # catch the device between loop cycles (adb appears briefly), or after
   # re-flashing the old recovery and booting system:
   adb exec-out 'cat /proc/last_kmsg' > last-kmsg.log   # root not needed in TWRP
   # find: 'Kernel panic ... PC is at <symbol>' → guard that driver the same
   # way (graceful bail on missing DT props), commit to tune-2026-09-12,
   # dispatch kernel CI, swap device/samsung/star2lte/prebuilt/Image,
   # dispatch build-twrp.yml, repeat.
   ```
   Known-graceful drivers (fail without panic): sec_ts (touch), sec_nfc,
   s2mps18-rtc, sec_param/abc_hub. Already-fixed: GPU cooling, s2mpb02 LED.
6. Rescue if stuck in a loop: **Odin + `backup/recovery-twrp-3.7.0-omni.img`
   as tar.md5** (or `recovery-twrp-old.tar.md5` on the Windows desktop).
   All boot backups verified in `star2lte-tune/backup/`.

## Key files

| File | Purpose |
|---|---|
| `device/samsung/star2lte/` | handwritten TWRP 12.1 tree (aosp_base inherit, erofs vendor declared, v1 FBE policy, size diet) |
| `device/samsung/star2lte/prebuilt/Image` + `dt` | slim guarded kernel + DTBH (byte-identical across branches) |
| `vendor-blobs/` | Samsung keymaster3/phh/Trustonic blobs from the phone |
| `tools/samsung_pack.py` | Samsung v0+DTBH packer — **RAMDISK_PAD 8 bytes + cpio TRIM are mandatory** |
| `setup-tree.sh` | tree placement + blobs into `recovery/root/system/vendor/` |
| `local_manifests/remove-heavy.xml` | 88-project sync diet (all `optional="true"`) |
| `BUILD-FIX-HISTORY.md` | the full run-by-run saga |

## Hard rules learned (do not relearn the hard way)

1. Never flash the AOSP-format `recovery.img` on Samsung — DTBH-less = loop.
2. Never remove `packages/modules`, `art`, `libcore`, `packages/providers`,
   `prebuilts/sdk`, `prebuilts/rust` from the sync — each = a build break.
3. Swap AFTER sync; 8G swap for soong; free-disk step is mandatory.
4. `make clean` on the kernel tree loses the sound card (golden lineage rule).
5. Recovery ramdisk must end EXACTLY at the cpio TRAILER (+ the 8-byte SBL
   reserve handled by RAMDISK_PAD).
6. The SBL strips DT properties in recovery boots — audit every vendor
   driver that probes early for unguarded DT-derived pointers.
