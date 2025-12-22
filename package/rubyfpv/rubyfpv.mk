###############################################################################
#
# rubyfpv
#
###############################################################################

RUBYFPV_VERSION = 11.7
RUBYFPV_SITE = $(call github,RubyFPV,RubyFPV,$(RUBYFPV_VERSION))
RUBYFPV_SITE_METHOD = tar
RUBYFPV_INSTALL_STAGING = NO
RUBYFPV_INSTALL_TARGET = YES

# Library deps inferred from RubyFPV Makefile (RUBY_BUILD_ENV=radxa)
RUBYFPV_DEPENDENCIES = rockchip-mpp libdrm cairo libpcap libgpiod i2c-tools sdl2

# Provide compatibility headers: make a local pcap/pcap.h that includes
# whichever header exists in the toolchain sysroot (pcap/pcap.h or pcap.h).
define RUBYFPV_ADD_PCAP_COMPAT_HEADER
	mkdir -p $(@D)/br-compat/pcap
	printf "#ifndef BR_RUBYFPV_PCAP_SHIM\n#define BR_RUBYFPV_PCAP_SHIM\n\n/* This shim shadowing pcap/pcap.h must forward to the real header. */\n/* Use include_next to get the sysroot's pcap header, not this shim. */\n#ifdef __GNUC__\n  #include_next <pcap/pcap.h>\n#else\n  /* Fallback for non-GNU compilers: assume nested path exists */\n  #include <pcap/pcap.h>\n#endif\n\n#endif\n" > $(@D)/br-compat/pcap/pcap.h
endef

RUBYFPV_POST_EXTRACT_HOOKS += RUBYFPV_ADD_PCAP_COMPAT_HEADER

# Force-update all source includes from <pcap.h> to <pcap/pcap.h>
define RUBYFPV_REWRITE_PCAP_INCLUDES
	cd $(@D) && \
	find . \( -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.hpp" \) -print0 | \
	xargs -0 sed -i 's@<pcap.h>@<pcap/pcap.h>@g'
endef

RUBYFPV_POST_EXTRACT_HOOKS += RUBYFPV_REWRITE_PCAP_INCLUDES

# Adjust DRM include to libdrm path to match Buildroot sysroot
define RUBYFPV_REWRITE_DRM_INCLUDES
	cd $(@D) && \
	find . \( -name "*.c" -o -name "*.h" -o -name "*.cpp" -o -name "*.hpp" \) -print0 | \
	xargs -0 sed -i 's@<drm.h>@<libdrm/drm.h>@g'
endef

RUBYFPV_POST_EXTRACT_HOOKS += RUBYFPV_REWRITE_DRM_INCLUDES

# Ensure no stale local patches are applied (we rewrite sources instead)
define RUBYFPV_STRIP_LOCAL_PATCHES
	rm -f $(RUBYFPV_PKGDIR)/*.patch || true
endef

RUBYFPV_PRE_PATCH_HOOKS += RUBYFPV_STRIP_LOCAL_PATCHES

# Remove host include/library paths that break cross-compilation
define RUBYFPV_STRIP_HOST_PATHS
	# Rewrite across all Makefiles in the tree
	find $(@D) \( -name Makefile -o -name "*.mk" \) -print0 | xargs -0 -I{} sh -c \
	  "sed -i -E 's|[[:space:]]-I/usr/include/SDL\b||g' {} && \
	   sed -i -E 's|[[:space:]]-I/usr/include/SDL2\b||g' {} && \
	   sed -i -E 's|[[:space:]]-I/usr/include/libdrm\b||g' {} && \
	   sed -i -E 's|[[:space:]]-I/usr/include/drm\b||g' {} && \
	   sed -i -E 's|[[:space:]]-I/usr/include/freetype2\b||g' {} && \
	   sed -i -E 's|[[:space:]]-I/opt/vc/include[^[:space:]]*||g' {} && \
	   sed -i -E 's|[[:space:]]-L/usr/lib/arm-linux-gnueabihf\b||g' {} && \
	   sed -i -E 's|[[:space:]]-L/usr/lib/aarch64-linux-gnu\b||g' {} && \
	   sed -i -E 's|[[:space:]]-L/lib/aarch64-linux-gnu\b||g' {} && \
	   sed -i -E 's|[[:space:]]-lSDL\b||g' {} && \
	   # Ensure target compiler is used instead of host cc/gcc
	   sed -i -E 's/(^|[^[:alnum:]_])gcc([^[:alnum:]_]|$)/\\1$(CC)\\2/g' {} && \
	   sed -i -E 's/(^|[^[:alnum:]_])cc([^[:alnum:]_]|$)/\\1$(CC)\\2/g' {} && \
	   # Let env CC override local definitions
	   sed -i -E 's/^CC[[:space:]]*:?=([[:space:]]*)/CC ?=\1/g' {} " || true
endef

RUBYFPV_POST_EXTRACT_HOOKS += RUBYFPV_STRIP_HOST_PATHS

# Build all station binaries for Radxa/DRM+Cairo path
define RUBYFPV_BUILD_CMDS
		# Fix upstream Makefiles before build: ensure cross tools and strip host paths
		find $(@D) \( -name Makefile -o -name "*.mk" \) -print0 | \
		while IFS= read -r -d '' f; do \
			sed -i -E "s|^([[:space:]]*)gcc([[:space:]])|\\1$(TARGET_CC)\\2|g" "$${f}"; \
			sed -i -E "s|^([[:space:]]*)cc([[:space:]])|\\1$(TARGET_CC)\\2|g" "$${f}"; \
			sed -i -E "s|^([[:space:]]*)g\+\+([[:space:]])|\\1$(TARGET_CXX)\\2|g" "$${f}"; \
			sed -i -E 's|[[:space:]]-I/opt/vc/include[^[:space:]]*||g' "$${f}"; \
			sed -i -E 's|[[:space:]]-I/usr/include/SDL2||g' "$${f}"; \
			sed -i -E 's|[[:space:]]-I/usr/include/SDL||g' "$${f}"; \
			sed -i -E 's|[[:space:]]-I/usr/include/libdrm||g' "$${f}"; \
			sed -i -E 's|[[:space:]]-I/usr/include/drm||g' "$${f}"; \
			sed -i -E 's|[[:space:]]-I/usr/include/freetype2||g' "$${f}"; \
		done

		# Also patch the top Makefile explicitly
		sed -i -E "s|^([[:space:]]*)gcc([[:space:]])|\\1$(TARGET_CC)\\2|g" $(@D)/Makefile
		sed -i -E "s|^([[:space:]]*)cc([[:space:]])|\\1$(TARGET_CC)\\2|g" $(@D)/Makefile
		sed -i -E "s|^([[:space:]]*)g\+\+([[:space:]])|\\1$(TARGET_CXX)\\2|g" $(@D)/Makefile
		sed -i -E 's|-I/opt/vc[^ ]*||g' $(@D)/Makefile

	# Clean to drop any stale host-arch objects
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) clean

	$(TARGET_MAKE_ENV) \
	CPPFLAGS="$(TARGET_CPPFLAGS) -I$(@D)/br-compat -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/libdrm -I$(STAGING_DIR)/usr/include/drm -I$(STAGING_DIR)/usr/include/pcap -include pcap/pcap.h" \
	CFLAGS="$(TARGET_CFLAGS) -I$(@D)/br-compat -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/libdrm -I$(STAGING_DIR)/usr/include/drm -I$(STAGING_DIR)/usr/include/pcap -include pcap/pcap.h" \
	CXXFLAGS="$(TARGET_CXXFLAGS) -I$(@D)/br-compat -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/libdrm -I$(STAGING_DIR)/usr/include/drm -I$(STAGING_DIR)/usr/include/pcap -include pcap/pcap.h" \
	EXTRA_CPPFLAGS="-I$(@D)/br-compat -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/libdrm -I$(STAGING_DIR)/usr/include/drm -I$(STAGING_DIR)/usr/include/pcap -include pcap/pcap.h" \
	CC="$(TARGET_CC) -I$(@D)/br-compat -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/libdrm -I$(STAGING_DIR)/usr/include/drm -I$(STAGING_DIR)/usr/include/pcap -include pcap/pcap.h" \
	CXX="$(TARGET_CXX) -I$(@D)/br-compat -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/libdrm -I$(STAGING_DIR)/usr/include/drm -I$(STAGING_DIR)/usr/include/pcap -include pcap/pcap.h" \
	LDFLAGS="$(TARGET_LDFLAGS) -L$(STAGING_DIR)/usr/lib -lSDL2" \
	$(MAKE) -C $(@D) all RUBY_BUILD_ENV=radxa
endef

# Minimal runtime set for ground-station; install if present
define RUBYFPV_INSTALL_TARGET_CMDS
	mkdir -p $(TARGET_DIR)/usr/bin
	set -e; \
	for f in \
	  ruby_start ruby_i2c ruby_logger ruby_initdhcp ruby_sik_config ruby_alive \
	  ruby_video_proc ruby_update ruby_update_worker ruby_dbg \
	  ruby_tx_telemetry ruby_controller ruby_rt_station ruby_tx_rc ruby_rx_telemetry \
	  ruby_player_radxa ruby_central; do \
	  if [ -f $(@D)/$$f ]; then \
	    $(INSTALL) -D -m 0755 $(@D)/$$f $(TARGET_DIR)/usr/bin/$$f; \
	  fi; \
	done

	# Init script and helper wrapper
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/rubyfpv/files/S99rubyfpv \
		$(TARGET_DIR)/etc/init.d/S99rubyfpv
	$(INSTALL) -D -m 0755 $(BR2_EXTERNAL_OPENIPC_SBC_GS_PATH)/package/rubyfpv/files/rubyfpv.sh \
		$(TARGET_DIR)/usr/bin/rubyfpv.sh
endef

$(eval $(generic-package))
