TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_NO_BOOTLOADER := true
TARGET_BOARD_PLATFORM := exynos9810
TARGET_BOOTLOADER_BOARD_NAME := universal9810
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := cortex-a73
TARGET_CPU_VARIANT_RUNTIME := cortex-a73
# no TARGET_2ND_ARCH: recovery is 64-bit only — halves the ninja graph
# (every lib would otherwise compile twice: [arm64] + [arm])
TARGET_SUPPORTS_64_BIT_APPS := true

# kernel: prebuilt from kernel-s9plus-hdmi (susfs-v2-experiment line) — carries
# the ROM-era fscrypt + Trustonic drivers the FBE decrypt needs
TARGET_PREBUILT_KERNEL := device/samsung/star2lte/prebuilt/Image
BOARD_EXYNOS_DT_IMAGE := device/samsung/star2lte/prebuilt/dt

BOARD_KERNEL_BASE := 0x10000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x01000000
BOARD_TAGS_OFFSET := 0x00000100
BOARD_KERNEL_CMDLINE := androidboot.hardware=star2lte
BOARD_BOOT_HEADER_VERSION := 0

BOARD_BOOTIMAGE_PARTITION_SIZE := 57671680
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 68149248
BOARD_FLASH_BLOCK_SIZE := 4096

# separate vendor partition (erofs on PE13) — without this the build makes
# root/vendor a symlink to /system/vendor and the recovery ramdisk rsync
# collides with the health/sepolicy modules' recovery/root/vendor/etc files
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
TARGET_COPY_OUT_VENDOR := vendor

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_USES_FULL_RECOVERY_IMAGE := false
BOARD_SUPPRESS_SECURE_ERASE := true

TARGET_RECOVERY_FSTAB := device/samsung/star2lte/recovery/root/etc/recovery.fstab

TARGET_OTA_ASSERT_DEVICE := star2lte

# --- TWRP ---
TW_THEME := portrait_hdpi
DEVICE_SCREEN_WIDTH := 1440
DEVICE_SCREEN_HEIGHT := 2960
RECOVERY_SDCARD_ON_DATA := true
TW_INTERNAL_STORAGE_PATH := "/data/media/0"
TW_INTERNAL_STORAGE_MOUNT_POINT := "sdcard"
TW_EXTERNAL_STORAGE_PATH := "/external_sd"
TW_EXTERNAL_STORAGE_MOUNT_POINT := "external_sd"

# FBE decrypt — PE13 ROM uses legacy v1 policies (fileencryption=aes-256-xts,
# no :v2 marker, no metadata encryption — verified from /vendor/etc/fstab)
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_FBE := true
TW_USE_FSCRYPT_POLICY := 1
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true

TW_BRIGHTNESS_PATH := "/sys/class/backlight/panel/brightness"
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 162
TW_HAS_DOWNLOAD_MODE := true
TW_NO_REBOOT_BOOTLOADER := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_EXTRA_LANGUAGES := false
TW_NO_SCREEN_TIMEOUT := true
TW_INPUT_BLACKLIST := "hbtp_vm"
