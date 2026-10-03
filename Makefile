TARGET := iphone:clang:15.6:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = KYCTest

KYCTest_FILES = main.m KYCAppDelegate.m KYCViewController.m
KYCTest_FRAMEWORKS = UIKit Foundation AVFoundation CoreMedia CoreVideo QuartzCore
KYCTest_CFLAGS = -fobjc-arc -O2

include $(THEOS_MAKE_PATH)/application.mk
