#############################################################
#
# tar + squashfs to archive target filesystem
#
#############################################################

ROOTFS_RECOVERY_AML_DEPENDENCIES = linux rootfs-tar_aml host-python

RECOVERY_AML_ARGS = -b '$(BR2_TARGET_ROOTFS_RECOVERY_AML_BOARDNAME)'
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_WIPE_USERDATA),y)
  RECOVERY_AML_ARGS += -w
endif
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_WIPE_USERDATA_CONDITIONAL),y)
  RECOVERY_AML_ARGS += -c
endif

ifneq ($(strip $(BR2_TARGET_ROOTFS_RECOVERY_RECOVERY_IMG)),"")

# Check if recovery.img exists
  $(if $(wildcard $(BR2_TARGET_ROOTFS_RECOVERY_RECOVERY_IMG)),,$(fatal recovery.img does not exist (Path: $(BR2_TARGET_ROOTFS_RECOVERY_RECOVERY_IMG)).))

  
  RECOVERY_AML_ARGS += -r
endif

# Introduce imgpack
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_IMGPACK), y)

# We set default folder for res_pack resources
RES_PACK = fs/recovery_aml/res_pack

# Change it if custom folder is specified
ifneq ($(strip $(BR2_TARGET_ROOTFS_RECOVERY_AML_IMGPACK_CUSTOM)),"")
RES_PACK = $(BR2_TARGET_ROOTFS_RECOVERY_AML_IMGPACK_CUSTOM)
endif

# Check if AML_IMGPACK folder exists
$(if $(wildcard $(RES_PACK)),,$(fatal RES_PACK=$(RES_PACK), folder does not exist.))

RECOVERY_AML_ARGS += -l

endif

# Check for UPDATE_ZIP_PREFIX to override file name
# Default is to use boardname
ifneq ($(strip $(BR2_TARGET_ROOTFS_RECOVERY_AML_UPDATE_ZIP_PREFIX)),"")
    UPDATE_ZIP_PREFIX = $(BR2_TARGET_ROOTFS_RECOVERY_AML_UPDATE_ZIP_PREFIX)
else
    UPDATE_ZIP_PREFIX = $(BR2_TARGET_ROOTFS_RECOVERY_AML_BOARDNAME)
endif

ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_UPDATE_IMG),y)
  UPDATE_FORMAT = img
else
  UPDATE_FORMAT = zip
endif

ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_UPDATE_ZIP_NAME_FULL_DATETIME),y)
  UPDATE_ZIP = $(UPDATE_ZIP_PREFIX)-$(shell date -u %0d%^b%Y-%H%M%S)-update.$(UPDATE_FORMAT)
endif
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_UPDATE_ZIP_NAME_SHORT_DATE),y)
  UPDATE_ZIP = $(UPDATE_ZIP_PREFIX)-$(shell date -u +%Y%m%d)-update.$(UPDATE_FORMAT)
endif
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_UPDATE_ZIP_NAME_BOARDNAME_UPDATE_ZIP),y)
  UPDATE_ZIP = $(UPDATE_ZIP_PREFIX)-update.$(UPDATE_FORMAT)
endif
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_UPDATE_ZIP_NAME_UPDATE_ZIP),y)
  UPDATE_ZIP = update.$(UPDATE_FORMAT)
endif
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_UPDATE_ZIP_NAME_CUSTOM),y)
  UPDATE_ZIP = $(BR2_TARGET_ROOTFS_RECOVERY_AML_UPDATE_ZIP_NAME_CUSTOM_STRING)-update.$(UPDATE_FORMAT)
endif

# If we use imgpack, append ROOTFS_RECOVERY_AML_CMD with aditional commands
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_IMGPACK),y)

ROOTFS_RECOVERY_AML_CMD += \
    echo "Creating logo.img..." && \
    fs/recovery_aml/imgpack -r $(RES_PACK) $(BINARIES_DIR)/aml_recovery/logo.img && 

ADDITIONAL_FILES += " logo.img"

else

ifneq ($(strip $(BR2_TARGET_ROOTFS_RECOVERY_AML_LOGO)),"")
AML_LOGO = $(BR2_TARGET_ROOTFS_RECOVERY_AML_LOGO)
else
AML_LOGO = fs/recovery_aml/aml_logo.img
endif

# Check if AML_LOGO exists
$(if $(wildcard $(AML_LOGO)),,$(fatal AML_LOGO=$(AML_LOGO), file does not exist.))

# Aditional files to be included in package, by default only aml_logo.img
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_BOARDNAME),"stvmx")
ADDITIONAL_FILES = logo.img
else
ADDITIONAL_FILES = aml_logo.img
endif

ROOTFS_RECOVERY_AML_CMD = \
    mkdir -p $(BINARIES_DIR)/aml_recovery/system &&
endif

###### Advanced options ######

# Memory type
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_ADV_EMMC),y)
RECOVERY_AML_ARGS += -m EMMC
else ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_ADV_MTD),y)
RECOVERY_AML_ARGS += -m MTD
else
RECOVERY_AML_ARGS += -m UBI
endif

# File system for system and data partitions
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_ADV_FS_EXT4),y)
RECOVERY_AML_ARGS += -f ext4
else ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_ADV_FS_YAFFS2),y)
RECOVERY_AML_ARGS += -f yaffs2
else
RECOVERY_AML_ARGS += -f ubifs
endif

# Path to system partition in recovery
RECOVERY_AML_ARGS += -s $(BR2_TARGET_ROOTFS_RECOVERY_AML_ADV_PATH_SYSTEM)

# Path to data partition in recovery
RECOVERY_AML_ARGS += -d $(BR2_TARGET_ROOTFS_RECOVERY_AML_ADV_PATH_DATA)

# Check if NFTL partition exists, if it does provide path (without leading partition no)
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_ADV_NFTL),y)
RECOVERY_AML_ARGS += -n $(BR2_TARGET_ROOTFS_RECOVERY_AML_ADV_NFTL_PATH)
else
RECOVERY_AML_ARGS += -n none
endif

###### Advanced options ######

# If we have provided recovery.img, make sure it's included in update.zip
ifneq ($(strip $(BR2_TARGET_ROOTFS_RECOVERY_RECOVERY_IMG)),"")

ROOTFS_RECOVERY_AML_CMD += \
    echo "Copy recovery.img..." && \
    cp -f $(BR2_TARGET_ROOTFS_RECOVERY_RECOVERY_IMG) $(BINARIES_DIR)/aml_recovery/recovery.img && 

ADDITIONAL_FILES += " recovery.img"
endif

ROOTFS_RECOVERY_AML_CMD += \
    tar -C $(BINARIES_DIR)/aml_recovery/system -xf $(BINARIES_DIR)/rootfs.tar && \
    mkdir -p $(BINARIES_DIR)/aml_recovery/META-INF/com/google/android/ && \
    PYTHONDONTWRITEBYTECODE=1 $(HOST_DIR)/usr/bin/python fs/recovery_aml/android_scriptgen $(RECOVERY_AML_ARGS) -i -p $(BINARIES_DIR)/aml_recovery/system -o \
     $(BINARIES_DIR)/aml_recovery/META-INF/com/google/android/updater-script && \
    cp -f fs/recovery_aml/update-binary $(BINARIES_DIR)/aml_recovery/META-INF/com/google/android/ &&

ifneq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_IMGPACK),y)
ifeq ($(BR2_TARGET_ROOTFS_RECOVERY_AML_BOARDNAME),"stvmx")
ROOTFS_RECOVERY_AML_CMD += \
    cp -f $(AML_LOGO) $(BINARIES_DIR)/aml_recovery/logo.img &&
else
ROOTFS_RECOVERY_AML_CMD += \
    cp -f $(AML_LOGO) $(BINARIES_DIR)/aml_recovery/aml_logo.img &&
endif
endif

ROOTFS_RECOVERY_AML_CMD += \
    cp -f $(BINARIES_DIR)/uImage $(BINARIES_DIR)/aml_recovery/ && \
    find $(BINARIES_DIR)/aml_recovery/system/ -type l -delete && \
    find $(BINARIES_DIR)/aml_recovery/system/ -type d -empty -exec sh -c 'echo "dummy" > "{}"/.empty' \; && \
    pushd $(BINARIES_DIR)/aml_recovery/ >/dev/null && \
    zip -m -q -r -y $(BINARIES_DIR)/aml_recovery/update-unsigned.zip $(ADDITIONAL_FILES) uImage META-INF system && \
    popd >/dev/null && \
    echo "Signing $(UPDATE_ZIP)..." && \
    pushd fs/recovery_aml/ >/dev/null; java -Xmx1024m -jar signapk.jar -w testkey.x509.pem testkey.pk8 $(BINARIES_DIR)/aml_recovery/update-unsigned.zip '$(BINARIES_DIR)/$(UPDATE_ZIP)' && \
    rm -rf $(BINARIES_DIR)/aml_recovery; rm -f $(TARGET_DIR)/usr.sqsh

$(eval $(call ROOTFS_TARGET,recovery_aml))
