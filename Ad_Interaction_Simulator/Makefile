THEOS_DEVICE_IP = 172.19.193.18
#THEOS_DEVICE_PORT=2222
export ARCHS = arm64

include $(THEOS)/makefiles/common.mk
TARGET = iphone:14.2:13.0
SYSROOT = $(THEOS)/sdks/iPhoneOS14.2.sdk
travseiosapp_LDFLAGS += -F$(SYSROOT)/System/Library/PrivateFrameworks

TWEAK_NAME = travseiosapp
travseiosapp_FILES = adClassName.xm Tweak.xm CheckScript.xm GenerateEvent.xm Executor.xm DealwithException.xm CollectingLayoutTree.xm CollectFeature.xm QuickSort.xm FetchLayout.xm FindUITarget.xm
travseiosapp_FRAMEWORKS = UIKit WebKit PTFakeTouch
travseiosapp_EXTRA_FRAMEWORKS = PTFakeTouch 

#travseiosapp_LDFLAGS = -lsimulatetouch
travseiosapp_LIBRARIES = rocketbootstrap
travseiosapp_PRIVATE_FRAMEWORKS = AppSupport ChatKit IMFoundation IDS IMCore IOSurface IOKit IOMobileFramebuffer PTFakeTouch
# ${TWEAK_NAME}_CFLAGS = -I./header/ -I$(THEOS)/lib/PTFakeTouch.framework/Headers
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"