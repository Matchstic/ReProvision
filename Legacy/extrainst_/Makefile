include $(THEOS)/makefiles/common.mk

export ARCHS = armv7 armv7s arm64
export TARGET = iphone:clang:8.4:8.4
GO_EASY_ON_ME = 1

TOOL_NAME = extrainst_
extrainst__FILES = main.mm SSZipArchive/SSZipArchive.m SSZipArchive/minizip/ioapi.c SSZipArchive/minizip/mztools.c SSZipArchive/minizip/unzip.c SSZipArchive/minizip/zip.c SSZipArchive/aes/aescrypt.c SSZipArchive/aes/aeskey.c SSZipArchive/aes/aestab.c SSZipArchive/aes/entropy.c SSZipArchive/aes/fileenc.c SSZipArchive/aes/hmac.c SSZipArchive/aes/prng.c SSZipArchive/aes/pwd2key.c SSZipArchive/aes/sha1.c SAMKeychain/SAMKeychain.m SAMKeychain/SAMKeychainQuery.m
extrainst__LDFLAGS = -lz
extrainst__PRIVATE_FRAMEWORKS = MobileCoreServices
extrainst__FRAMEWORKS = Security
extrainst__CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk

package::
	cp .theos/_/usr/bin/extrainst_ ../Extender-Installer/Package/DEBIAN/
	@rm -f packages/*.deb
