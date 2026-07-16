INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e
TARGET = iphone:clang:16.5:16.0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = WolfGps
WolfGps_FILES = Tweak.x GPSApiLocal.mm GPSWolfoxDesign.mm WolfoxSpoofStore.m WolfoxSpoofOverlay.m
WolfGps_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable
WolfGps_CCFLAGS = -std=c++17
WolfGps_FRAMEWORKS = UIKit CoreLocation CoreBluetooth MapKit Security SystemConfiguration
include $(THEOS_MAKE_PATH)/tweak.mk
