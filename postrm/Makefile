include $(THEOS)/makefiles/common.mk

TOOL_NAME = postrm
postrm_FILES = main.mm

include $(THEOS_MAKE_PATH)/tool.mk

package::
	cp .theos/_/usr/bin/postrm ../Extender-Installer/Package/DEBIAN/
	@rm -f packages/*.deb