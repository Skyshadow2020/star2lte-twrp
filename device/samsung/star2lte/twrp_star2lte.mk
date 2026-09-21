$(call inherit-product, device/samsung/star2lte/device.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)

PRODUCT_DEVICE := star2lte
PRODUCT_NAME := twrp_star2lte
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-G965F
PRODUCT_MANUFACTURER := samsung

TARGET_DEVICE := star2lte
