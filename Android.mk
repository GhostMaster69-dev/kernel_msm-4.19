LOCAL_PATH := $(call my-dir)

ifneq ($(filter land prada santoni ugg,$(TARGET_DEVICE)),)

KERNEL_OUT := $(TARGET_OUT_INTERMEDIATES)/KERNEL_OBJ
KERNEL_HEADERS_INSTALL := $(KERNEL_OUT)/usr

$(KERNEL_HEADERS_INSTALL): | $(KERNEL_OUT)
	mkdir -p $(KERNEL_HEADERS_INSTALL)
	cp -Rf $(LOCAL_PATH)/kernel_headers/* $(KERNEL_HEADERS_INSTALL)/

endif
