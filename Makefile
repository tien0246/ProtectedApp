ARCHS = arm64 arm64e
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
IGNORE_WARNINGS = 1
GO_EASY_ON_ME = 1

# THEOS_DEVICE_IP = 127.0.0.1
# THEOS_DEVICE_PORT = 2222
THEOS_DEVICE_IP = 192.168.1.5
THEOS_DEVICE_PORT = 22

TARGET := iphone:clang:latest:14.0
# INSTALL_TARGET_PROCESSES = Messenger

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
    THEOS_PACKAGE_DIR = packages/rootless
else
    THEOS_PACKAGE_DIR = packages/rootful
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ProtectedApp

$(TWEAK_NAME)_CFLAGS = -fobjc-arc -fvisibility=hidden

$(TWEAK_NAME)_CCFLAGS = -std=c++11 -fno-rtti -fno-exceptions -DNDEBUG -fno-objc-arc -O2

${TWEAK_NAME}_FILES = Tweak.xm

${TWEAK_NAME}_CFLAGS = -fobjc-arc

$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Messenger"

clean::
	rm -rf .theos
