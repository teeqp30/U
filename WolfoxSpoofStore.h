#pragma once
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>

@interface WolfoxSpoofStore : NSObject

// الموقع
@property (nonatomic, assign) CLLocationCoordinate2D fakeCoords;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL hasStoredLocation;

// الارتجاج
@property (nonatomic, assign) BOOL isJitterActive;
@property (nonatomic, assign) double jitterDistance;

// الانجراف
@property (nonatomic, assign) double driftLatitude;
@property (nonatomic, assign) double driftLongitude;

// المفضلة
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *favorites;

// الإخفاء الذكي
@property (nonatomic, assign) BOOL toolHidden;
@property (nonatomic, assign) BOOL isPermanentlyHidden;
@property (nonatomic, assign) NSInteger hideClickCount;

// محاكاة الكاميرا
@property (nonatomic, assign) BOOL cameraSimEnabled;
@property (nonatomic, strong) UIImage *simulatedCameraImage;

// التفعيل
@property (nonatomic, strong) NSString *activationCode;
@property (nonatomic, strong) NSString *deviceUUID;
@property (nonatomic, assign) BOOL isActivated;
@property (nonatomic, strong) NSString *expiresAt;

// نوع الخريطة
@property (nonatomic, assign) NSInteger mapType; // 0=عادي 1=قمر صناعي 2=مختلط

+ (instancetype)shared;
- (void)save;
- (void)load;
- (NSString *)getDeviceUUID;

@end
