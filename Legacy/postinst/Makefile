include $(THEOS)/makefiles/common.mk

export ARCHS = armv7 armv7s arm64
export TARGET = iphone:clang:8.4:8.4
GO_EASY_ON_ME = 1

TOOL_NAME = postinst
postinst_FILES = main.mm
postinst_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk

package::
	cp .theos/_/usr/bin/postinst ../Extender-Installer/Package/DEBIAN/
	@rm -f packages/*.deb
