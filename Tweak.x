// ============================================================
//  Wolf Gps — Tweak.x
//  تزييف الموقع + محاكاة الكاميرا + تخطي الحماية
//  السيرفر: https://api.p3nd.fun
// ============================================================

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "WolfoxSpoofStore.h"

// ============================================================
//  تزييف الموقع — CLLocationManager
// ============================================================

%hook CLLocationManager

- (void)setDelegate:(id<CLLocationManagerDelegate>)delegate {
    if (delegate) {
        // هوك ديناميكي للـ delegate لتجنب هوك NSObject العام
        %orig(delegate);
    } else {
        %orig;
    }
}

- (void)startUpdatingLocation {
    %orig;
}

%end

// ============================================================
//  تزييف الموقع — CLLocation
// ============================================================

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    if (!store.isActive || !store.hasStoredLocation) {
        return %orig;
    }

    CLLocationCoordinate2D coords = store.fakeCoords;

    if (store.isJitterActive) {
        double jitter = store.jitterDistance / 111320.0;
        double dLat = ((double)arc4random() / UINT32_MAX - 0.5) * 2.0 * jitter;
        double dLon = ((double)arc4random() / UINT32_MAX - 0.5) * 2.0 * jitter;
        coords.latitude  += dLat;
        coords.longitude += dLon;
    }

    return coords;
}

- (CLLocationAccuracy)horizontalAccuracy {
    if (![WolfoxSpoofStore shared].isActive) {
        return %orig;
    }
    return 5.0;
}

%end

// ============================================================
//  تخطي حماية الجلبريك - تحسين الأداء والأمان
// ============================================================

%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    if ([path containsString:@"/Applications/Cydia.app"] || 
        [path containsString:@"/Applications/Sileo.app"] ||
        [path containsString:@"/usr/bin/ssh"] ||
        [path containsString:@"/var/jb"]) {
        return NO;
    }
    return %orig;
}

%end

// ============================================================
//  تهيئة الأداة
// ============================================================

extern void WolfGpsInitUI(void);

%hook SpringBoard

- (void)applicationDidFinishLaunching:(id)app {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        WolfGpsInitUI();
    });
}

%end

%ctor {
    @autoreleasepool {
        [[WolfoxSpoofStore shared] load];
    }
}
