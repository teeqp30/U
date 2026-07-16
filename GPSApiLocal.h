#pragma once
#import <Foundation/Foundation.h>

#define WOLF_API_BASE @"https://api.p3nd.fun/api"
#define WOLF_API_KEY  @"WolfGps_2Hy_Secret_2026"

@interface GPSApiLocal : NSObject
+ (instancetype)shared;
- (void)activateCode:(NSString *)code completion:(void(^)(BOOL success, NSString *message, NSString *expiresAt))completion;
- (void)checkCode:(NSString *)code deviceUUID:(NSString *)uuid completion:(void(^)(BOOL valid, NSString *expiresAt))completion;
@end
