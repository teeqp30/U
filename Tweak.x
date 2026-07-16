// ============================================================
//  Wolf Gps — Tweak.x (Logos Edition)
//  تزييف الموقع + محاكاة الكاميرا + تخطي الحماية
//  السيرفر: https://api.p3nd.fun
// ============================================================

#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "WolfoxSpoofStore.h"
#import "WolfoxSpoofOverlay.h"

// -------------- License API --------------
#import "GPSWolfoxAPI.h"

// -------------- Helpers --------------
static UIWindow *WolfoxCurrentWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) if (window.isKeyWindow) return window;
        }
    }
    return app.keyWindow ?: app.windows.firstObject;
}

static void WolfoxEnableTool(void) {
    if (!GPSLicenseIsAuthorized()) return;
    UIWindow *win = WolfoxCurrentWindow();
    if (!win) return;
    if ([WolfoxSpoofOverlay shared].view.superview != win) {
        [[WolfoxSpoofOverlay shared].view removeFromSuperview];
        [win addSubview:[WolfoxSpoofOverlay shared].view];
    }
    [WolfoxSpoofOverlay shared].view.hidden = NO;
}

// ============================================================
//  تزييف الموقع — CLLocation
// ============================================================

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    if (store.isActive) {
        CLLocationCoordinate2D base = store.isRouteActive ? store.currentMovingCoords : store.fakeCoords;
        return CLLocationCoordinate2DMake(base.latitude + store.driftLatitude, base.longitude + store.driftLongitude);
    }
    return %orig;
}

%end

// ============================================================
//  تخطي حماية الجلبريك
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
        GPSLicenseStart();
    });
}
%end

%ctor {
    @autoreleasepool {
        [[WolfoxSpoofStore shared] load];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:GPSLicenseAuthorizedNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            if (![WolfoxSpoofStore shared].toolHidden) {
                WolfoxEnableTool();
            }
        }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:GPSLicenseRevokedNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) {
            [WolfoxSpoofOverlay shared].view.hidden = YES;
        }];
    }
}
