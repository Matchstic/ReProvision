include $(THEOS)/makefiles/common.mk

TOOL_NAME = postinst
postinst_FILES = main.mm

include $(THEOS_MAKE_PATH)/tool.mk

package::
	cp .theos/_/usr/bin/postinst ../Extender-Installer/Package/DEBIAN/
	@rm -f packages/*.deb
