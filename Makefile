INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WolfGps

WolfGps_FILES = Tweak.x WolfoxSpoofStore.m WolfoxSpoofOverlay.m GPSWolfoxDesign.mm GPSApiLocal.mm
WolfGps_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unused-but-set-variable
WolfGps_CCFLAGS = -std=c++17
WolfGps_FRAMEWORKS = UIKit CoreLocation CoreBluetooth MapKit Security SystemConfiguration AVFoundation

include $(THEOS_MAKE_PATH)/tweak.mk
