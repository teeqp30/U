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

- (void)startUpdatingLocation {
    %orig;
}

- (void)requestLocation {
    %orig;
}

%end

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    if (!store.isActive || !store.hasStoredLocation) return %orig;

    CLLocationCoordinate2D coords = store.fakeCoords;

    // الارتجاج
    if (store.isJitterActive) {
        double jitter = store.jitterDistance / 111320.0;
        double dLat = ((double)arc4random() / UINT32_MAX - 0.5) * 2.0 * jitter;
        double dLon = ((double)arc4random() / UINT32_MAX - 0.5) * 2.0 * jitter;
        coords.latitude  += dLat;
        coords.longitude += dLon;
    }

    return coords;
}

- (CLLocationDistance)altitude { return %orig; }
- (CLLocationAccuracy)horizontalAccuracy {
    if (![WolfoxSpoofStore shared].isActive) return %orig;
    return 5.0;
}
- (CLLocationAccuracy)verticalAccuracy { return %orig; }
- (CLLocationSpeed)speed { return %orig; }
- (CLLocationDirection)course { return %orig; }

%end

// ============================================================
//  تزييف الموقع — CLLocationManagerDelegate
// ============================================================

%hook NSObject

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    if (!store.isActive || !store.hasStoredLocation) {
        %orig;
        return;
    }

    CLLocationCoordinate2D coords = store.fakeCoords;
    if (store.isJitterActive) {
        double jitter = store.jitterDistance / 111320.0;
        coords.latitude  += ((double)arc4random() / UINT32_MAX - 0.5) * 2.0 * jitter;
        coords.longitude += ((double)arc4random() / UINT32_MAX - 0.5) * 2.0 * jitter;
    }

    CLLocation *fakeLoc = [[CLLocation alloc] initWithLatitude:coords.latitude longitude:coords.longitude];
    %orig(manager, @[fakeLoc]);
}

%end

// ============================================================
//  محاكاة الكاميرا — UIImagePickerController
// ============================================================

%hook UIImagePickerController

- (void)viewDidLoad {
    %orig;
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    if (!store.cameraSimEnabled || !store.simulatedCameraImage) return;
    if (self.sourceType != UIImagePickerControllerSourceTypeCamera) return;

    // استبدال الكاميرا بالصورة المحددة
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([self.delegate respondsToSelector:@selector(imagePickerController:didFinishPickingMediaWithInfo:)]) {
            NSDictionary *info = @{
                UIImagePickerControllerOriginalImage: store.simulatedCameraImage,
                UIImagePickerControllerMediaType: @"public.image"
            };
            [self.delegate imagePickerController:self didFinishPickingMediaWithInfo:info];
        }
    });
}

%end

// ============================================================
//  تخطي حماية الجلبريك — JailbreakBypass
// ============================================================

// إخفاء وجود ملفات الجلبريك
%hook NSFileManager

- (BOOL)fileExistsAtPath:(NSString *)path {
    static NSArray *jbPaths = nil;
    if (!jbPaths) {
        jbPaths = @[
            @"/Applications/Cydia.app",
            @"/Applications/Sileo.app",
            @"/Applications/Zebra.app",
            @"/usr/sbin/sshd",
            @"/usr/bin/ssh",
            @"/usr/libexec/ssh-keysign",
            @"/bin/bash",
            @"/bin/sh",
            @"/etc/apt",
            @"/var/lib/dpkg",
            @"/var/mobile/Library/Preferences/ABPattern",
            @"/usr/lib/libhooker.dylib",
            @"/usr/lib/TweakInject.dylib",
            @"/var/jb",
            @"/var/LIB",
            @"/var/ulb",
            @"/var/bin",
            @"/var/sbin",
            @"/var/lib/apt",
            @"/var/lib/cydia",
            @"/private/var/lib/apt",
            @"/private/var/lib/cydia",
            @"/private/var/stash",
            @"/private/var/jb",
        ];
    }
    for (NSString *p in jbPaths) {
        if ([path hasPrefix:p] || [path isEqualToString:p]) return NO;
    }
    return %orig;
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDir {
    static NSArray *jbPaths = nil;
    if (!jbPaths) {
        jbPaths = @[
            @"/Applications/Cydia.app", @"/Applications/Sileo.app",
            @"/usr/sbin/sshd", @"/bin/bash", @"/etc/apt",
            @"/var/lib/dpkg", @"/var/jb", @"/private/var/jb",
        ];
    }
    for (NSString *p in jbPaths) {
        if ([path hasPrefix:p] || [path isEqualToString:p]) return NO;
    }
    return %orig;
}

%end

// إخفاء مسارات الجلبريك من قوائم الملفات
%hook NSString

- (BOOL)hasSuffix:(NSString *)suffix {
    if ([suffix isEqualToString:@".dylib"]) {
        NSArray *blocked = @[@"substrate", @"substitute", @"libhooker", @"TweakInject", @"cycript"];
        for (NSString *b in blocked) {
            if ([self containsString:b]) return NO;
        }
    }
    return %orig;
}

%end

// إخفاء متغيرات البيئة المشبوهة
%hook NSProcessInfo

- (NSDictionary<NSString *, NSString *> *)environment {
    NSMutableDictionary *env = [%orig mutableCopy];
    NSArray *blocked = @[@"DYLD_INSERT_LIBRARIES", @"_MSSafeMode", @"_SafeMode"];
    for (NSString *k in blocked) [env removeObjectForKey:k];
    return [env copy];
}

%end

// ============================================================
//  تهيئة الأداة
// ============================================================

%ctor {
    @autoreleasepool {
        // تحميل الإعدادات المحفوظة
        [[WolfoxSpoofStore shared] load];
    }
}
