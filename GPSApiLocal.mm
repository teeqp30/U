#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import "GPSWolfoxAPI.h"

#ifndef GPS_API_BASE_URL
#define GPS_API_BASE_URL @"https://api.p3nd.fun/api"
#endif
#ifndef GPS_API_TOKEN
#define GPS_API_TOKEN @"gps_c11532a714400a3f53a0dffd1ea723e2511ede6bdcb3be9b"
#endif
#ifndef GPS_LOCAL_VERSION
#define GPS_LOCAL_VERSION @"3.2.0"
#endif

NSString *GPSApiBaseURL(void) { return GPS_API_BASE_URL; }
NSString *GPSApiAccessToken(void) { return GPS_API_TOKEN; }
NSString *GPSLocalVersion(void) { return GPS_LOCAL_VERSION; }



NSString * const GPSLicenseRequestFinishedNotification = @"GPSLicenseRequestFinishedNotification";

static NSString * const kGPSLicenseCodeKey = @"com.wolfox.gps.license.code";
static NSString * const kGPSDeviceUUIDKey = @"com.wolfox.gps.device.uuid";
static NSString * const kGPSExpiresKey = @"com.wolfox.gps.license.expires";
static NSString * const kGPSLastAnnouncementKey = @"com.wolfox.gps.last.announcement";

static UIWindow *GPSForegroundWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow) return window;
            }
        }
    }
    return app.keyWindow ?: app.windows.firstObject;
}

static UIViewController *GPSTopController(void) {
    UIViewController *controller = GPSForegroundWindow().rootViewController;
    while (controller) {
        if (controller.presentedViewController) { controller = controller.presentedViewController; continue; }
        if ([controller isKindOfClass:UINavigationController.class]) { controller = ((UINavigationController *)controller).visibleViewController; continue; }
        if ([controller isKindOfClass:UITabBarController.class]) { controller = ((UITabBarController *)controller).selectedViewController; continue; }
        break;
    }
    return controller;
}

static NSString *GPSKeychainRead(NSString *account) {
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService:@"com.wolfox.gps",
                            (__bridge id)kSecAttrAccount:account,
                            (__bridge id)kSecReturnData:@YES,
                            (__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitOne};
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) != errSecSuccess || !result) return nil;
    NSData *data = CFBridgingRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static void GPSKeychainWrite(NSString *account, NSString *value) {
    NSDictionary *base = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                           (__bridge id)kSecAttrService:@"com.wolfox.gps",
                           (__bridge id)kSecAttrAccount:account};
    SecItemDelete((__bridge CFDictionaryRef)base);
    if (!value.length) return;
    NSMutableDictionary *item = [base mutableCopy];
    item[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];
    item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    SecItemAdd((__bridge CFDictionaryRef)item, NULL);
}

static NSComparisonResult GPSCompareVersions(NSString *a, NSString *b) {
    return [a compare:b options:NSNumericSearch];
}

@interface GPSLicenseManager : NSObject
@property(nonatomic, assign, getter=isAuthorized) BOOL authorized;
@property(nonatomic, assign) BOOL requestInFlight;
@property(nonatomic, copy) NSString *licenseCode;
@property(nonatomic, copy) NSString *deviceUUID;
@property(nonatomic, copy) NSString *expiresAt;
@property(nonatomic, strong) NSTimer *checkTimer;
@property(nonatomic, strong) NSDictionary *serverSettings;
@property(nonatomic, assign) BOOL started;
+ (instancetype)shared;
- (void)start;
- (void)presentActivation;
- (void)checkNow;
- (void)resetCurrentDevice;
@end

@implementation GPSLicenseManager

+ (instancetype)shared {
    static GPSLicenseManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ manager = [GPSLicenseManager new]; });
    return manager;
}

- (instancetype)init {
    if ((self = [super init])) {
        _licenseCode = GPSKeychainRead(kGPSLicenseCodeKey) ?: @"";
        _deviceUUID = GPSKeychainRead(kGPSDeviceUUIDKey) ?: @"";
        _expiresAt = GPSKeychainRead(kGPSExpiresKey) ?: @"";
        if (!_deviceUUID.length) {
            _deviceUUID = NSUUID.UUID.UUIDString;
            GPSKeychainWrite(kGPSDeviceUUIDKey, _deviceUUID);
        }
    }
    return self;
}

- (void)start {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.started) return;
        self.started = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appBecameActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        [self fetchSettingsWithCompletion:^{
            if (self.licenseCode.length) [self checkNow];
            else [self presentActivation];
        }];
        self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:900.0 target:self selector:@selector(checkNow) userInfo:nil repeats:YES];
    });
}

- (void)appBecameActive {
    if (self.licenseCode.length) [self checkNow];
}

- (NSMutableURLRequest *)requestForEndpoint:(NSString *)endpoint body:(NSDictionary *)body {
    NSString *urlString = [NSString stringWithFormat:@"%@/%@.php", [GPSApiBaseURL() stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]], endpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];
    request.HTTPMethod = body ? @"POST" : @"GET";
    request.timeoutInterval = 20.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:GPSApiAccessToken() forHTTPHeaderField:@"X-GPS-API-KEY"];
    [request setValue:GPSLocalVersion() forHTTPHeaderField:@"X-GPS-App-Version"];
    if (body) request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    return request;
}

- (void)sendEndpoint:(NSString *)endpoint body:(NSDictionary *)body completion:(void (^)(NSDictionary *, NSInteger, NSError *))completion {
    NSMutableURLRequest *request = [self requestForEndpoint:endpoint body:body];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        NSDictionary *json = nil;
        if (data.length) {
            id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([object isKindOfClass:NSDictionary.class]) json = object;
        }
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(json ?: @{}, status, error); });
    }] resume];
}

- (void)notifyRequestFinished:(BOOL)ok message:(NSString *)message {
    NSDictionary *info = @{ @"ok": @(ok), @"message": message ?: @"" };
    [[NSNotificationCenter defaultCenter] postNotificationName:GPSLicenseRequestFinishedNotification object:nil userInfo:info];
}

- (void)fetchSettingsWithCompletion:(dispatch_block_t)completion {
    [self sendEndpoint:@"settings" body:nil completion:^(NSDictionary *json, NSInteger status, NSError *error) {
        if ([json[@"ok"] boolValue]) {
            self.serverSettings = json;
            [self processServerDirectives:json];
        }
        if (completion) completion();
    }];
}

- (void)processServerDirectives:(NSDictionary *)json {
    if ([json[@"maintenance"] boolValue]) {
        [self revokeWithMessage:@"الخدمة تحت الصيانة حاليًا. حاول لاحقًا."];
        return;
    }
    NSString *serverVersion = [json[@"app_version"] isKindOfClass:NSString.class] ? json[@"app_version"] : @"";
    BOOL updateRequired = [json[@"force_update"] boolValue] && serverVersion.length && GPSCompareVersions(GPSLocalVersion(), serverVersion) == NSOrderedAscending;
    if (updateRequired) {
        NSString *url = [json[@"update_url"] isKindOfClass:NSString.class] ? json[@"update_url"] : @"";
        [self showUpdateAlert:url required:YES];
    }
    NSString *announcement = [json[@"announcement"] isKindOfClass:NSString.class] ? json[@"announcement"] : @"";
    if (announcement.length) {
        NSString *last = [NSUserDefaults.standardUserDefaults stringForKey:kGPSLastAnnouncementKey];
        if (![last isEqualToString:announcement]) {
            [NSUserDefaults.standardUserDefaults setObject:announcement forKey:kGPSLastAnnouncementKey];
            [self showAlertTitle:@"إعلان" message:announcement actions:nil];
        }
    }
}

- (void)activateCode:(NSString *)code {
    if (self.requestInFlight) return;
    NSString *normalized = [[code stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if (!normalized.length) { [self showAlertTitle:@"تنبيه" message:@"أدخل كود التفعيل." actions:nil]; return; }
    self.requestInFlight = YES;
    NSDictionary *body = @{ @"code":normalized,
                            @"device_uuid":self.deviceUUID,
                            @"device_name":UIDevice.currentDevice.name ?: @"iPhone",
                            @"app_version":GPSLocalVersion() };
    [self sendEndpoint:@"activate" body:body completion:^(NSDictionary *json, NSInteger status, NSError *error) {
        self.requestInFlight = NO;
        if (error) { [self notifyRequestFinished:NO message:@"تعذر الاتصال بالخادم."]; [self showAlertTitle:@"تعذر الاتصال" message:@"تحقق من الإنترنت ثم حاول مرة أخرى." actions:nil]; return; }
        if (![json[@"ok"] boolValue]) { NSString *m = json[@"message"] ?: @"تعذر تفعيل الكود."; [self notifyRequestFinished:NO message:m]; [self showAlertTitle:@"فشل التفعيل" message:m actions:nil]; return; }
        self.licenseCode = normalized;
        self.expiresAt = [json[@"expires_at"] isKindOfClass:NSString.class] ? json[@"expires_at"] : @"";
        GPSKeychainWrite(kGPSLicenseCodeKey, self.licenseCode);
        GPSKeychainWrite(kGPSExpiresKey, self.expiresAt);
        [self authorize];
        [self notifyRequestFinished:YES message:@"تم التفعيل بنجاح"];
        [self showAlertTitle:@"تم التفعيل" message:[NSString stringWithFormat:@"تم تفعيل الجهاز بنجاح.\nالصلاحية: %@", self.expiresAt.length ? self.expiresAt : @"نشطة"] actions:nil];
    }];
}

- (void)checkNow {
    if (self.requestInFlight || !self.licenseCode.length) return;
    self.requestInFlight = YES;
    NSDictionary *body = @{ @"code":self.licenseCode, @"device_uuid":self.deviceUUID, @"app_version":GPSLocalVersion() };
    [self sendEndpoint:@"check" body:body completion:^(NSDictionary *json, NSInteger status, NSError *error) {
        self.requestInFlight = NO;
        if (error) {
            // لا نسحب التفعيل فورًا عند انقطاع مؤقت، لكن لا نفعّل نسخة لم تُتحقق سابقًا.
            if (!self.authorized && !self.expiresAt.length) [self presentActivation];
            return;
        }
        if (![json[@"ok"] boolValue]) {
            [self revokeWithMessage:json[@"message"] ?: @"الترخيص غير صالح."];
            return;
        }
        self.expiresAt = [json[@"expires_at"] isKindOfClass:NSString.class] ? json[@"expires_at"] : @"";
        GPSKeychainWrite(kGPSExpiresKey, self.expiresAt);
        [self processServerDirectives:json];
        if (![json[@"maintenance"] boolValue]) [self authorize];
    }];
}

- (void)authorize {
    if (self.authorized) return;
    self.authorized = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:GPSLicenseAuthorizedNotification object:nil];
}

- (void)revokeWithMessage:(NSString *)message {
    BOOL wasAuthorized = self.authorized;
    self.authorized = NO;
    if (wasAuthorized) [[NSNotificationCenter defaultCenter] postNotificationName:GPSLicenseRevokedNotification object:nil];
    if (message.length) [self showAlertTitle:@"الترخيص متوقف" message:message actions:@[[UIAlertAction actionWithTitle:@"إدخال كود" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){ [self presentActivation]; }]]];
}

- (void)presentActivation {
    dispatch_async(dispatch_get_main_queue(), ^{ GPSLicensePresentActivation(); });
}

- (void)resetCurrentDevice {
    if (!self.licenseCode.length) { [self presentActivation]; return; }
    NSDictionary *body = @{ @"code":self.licenseCode, @"device_uuid":self.deviceUUID };
    [self sendEndpoint:@"reset" body:body completion:^(NSDictionary *json, NSInteger status, NSError *error) {
        if (error) { [self showAlertTitle:@"تعذر الاتصال" message:@"لم يتم الوصول إلى خادم الرست." actions:nil]; return; }
        if (![json[@"ok"] boolValue]) { [self showAlertTitle:@"تعذر الرست" message:json[@"message"] ?: @"فشلت العملية." actions:nil]; return; }
        self.authorized = NO;
        self.licenseCode = @"";
        self.expiresAt = @"";
        GPSKeychainWrite(kGPSLicenseCodeKey, nil);
        GPSKeychainWrite(kGPSExpiresKey, nil);
        [[NSNotificationCenter defaultCenter] postNotificationName:GPSLicenseRevokedNotification object:nil];
        [self showAlertTitle:@"تم الرست" message:@"تم فك ارتباط الجهاز. تستطيع تفعيل الكود على جهاز آخر." actions:nil];
    }];
}

- (void)showUpdateAlert:(NSString *)url required:(BOOL)required {
    NSMutableArray *actions = [NSMutableArray array];
    if (url.length) [actions addObject:[UIAlertAction actionWithTitle:@"تحديث الآن" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *a){ [self openURL:url]; }]];
    if (!required) [actions addObject:[UIAlertAction actionWithTitle:@"لاحقًا" style:UIAlertActionStyleCancel handler:nil]];
    [self showAlertTitle:@"يتوفر تحديث" message:@"يجب تثبيت أحدث إصدار للمتابعة." actions:actions];
    if (required) [self revokeWithMessage:nil];
}

- (void)openURL:(NSString *)value {
    NSURL *url = [NSURL URLWithString:value ?: @""];
    if (!url) return;
    [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)message actions:(NSArray<UIAlertAction *> *)actions {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = GPSTopController();
        if (!top) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        if (actions.count) for (UIAlertAction *action in actions) [alert addAction:action];
        else [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا" style:UIAlertActionStyleDefault handler:nil]];
        [top presentViewController:alert animated:YES completion:nil];
    });
}

@end

#ifdef __cplusplus
extern "C" {
#endif
void GPSLicenseStart(void) { [[GPSLicenseManager shared] start]; }
BOOL GPSLicenseIsAuthorized(void) { return [GPSLicenseManager shared].isAuthorized; }
void GPSLicensePresentActivation(void) { [[GPSLicenseManager shared] presentActivation]; }
void GPSLicenseActivateCode(NSString *code) { [[GPSLicenseManager shared] activateCode:code ?: @""]; }
void GPSLicenseCheckNow(void) { [[GPSLicenseManager shared] checkNow]; }
void GPSLicenseResetCurrentDevice(void) { [[GPSLicenseManager shared] resetCurrentDevice]; }
NSString *GPSLicenseDeviceUUID(void) { return [GPSLicenseManager shared].deviceUUID; }
NSString *GPSLicenseExpiresAt(void) { return [GPSLicenseManager shared].expiresAt; }
NSString *GPSLicenseSupportURL(void) {
    NSString *value = [[GPSLicenseManager shared].serverSettings[@"support_url"] isKindOfClass:NSString.class] ? [GPSLicenseManager shared].serverSettings[@"support_url"] : @"";
    return value.length ? value : @"https://t.me/Wolf7569";
}
#ifdef __cplusplus
}
#endif
