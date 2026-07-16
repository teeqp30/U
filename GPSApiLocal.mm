#import "GPSApiLocal.h"
#import "WolfoxSpoofStore.h"

@implementation GPSApiLocal

+ (instancetype)shared {
    static GPSApiLocal *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[GPSApiLocal alloc] init]; });
    return s;
}

- (void)activateCode:(NSString *)code completion:(void(^)(BOOL, NSString *, NSString *))completion {
    NSString *uuid = [[WolfoxSpoofStore shared] getDeviceUUID];
    NSString *urlStr = [NSString stringWithFormat:@"%@/activate.php", WOLF_API_BASE];
    NSURL *url = [NSURL URLWithString:urlStr];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:WOLF_API_KEY forHTTPHeaderField:@"X-Gps-Api-Key"];

    NSDictionary *body = @{
        @"code": code,
        @"device_uuid": uuid,
        @"device_name": [[UIDevice currentDevice] name] ?: @"iPhone"
    };
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.timeoutIntervalForRequest = 15;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err || !data) {
            if (completion) completion(NO, @"خطأ في الاتصال بالسيرفر", nil);
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        BOOL ok = [json[@"ok"] boolValue];
        NSString *msg = json[@"message"] ?: @"";
        NSString *exp = json[@"expires_at"] ?: @"";
        if (completion) completion(ok, msg, exp);
    }] resume];
}

- (void)checkCode:(NSString *)code deviceUUID:(NSString *)uuid completion:(void(^)(BOOL, NSString *))completion {
    NSString *urlStr = [NSString stringWithFormat:@"%@/check.php", WOLF_API_BASE];
    NSURL *url = [NSURL URLWithString:urlStr];

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:WOLF_API_KEY forHTTPHeaderField:@"X-Gps-Api-Key"];

    NSDictionary *body = @{@"code": code, @"device_uuid": uuid};
    req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.timeoutIntervalForRequest = 10;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err || !data) { if (completion) completion(NO, nil); return; }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        BOOL ok = [json[@"ok"] boolValue];
        NSString *exp = json[@"expires_at"] ?: @"";
        if (completion) completion(ok, exp);
    }] resume];
}

@end
