#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface WolfoxSpoofStore : NSObject
@property (nonatomic, assign) BOOL toolHidden;
@property (nonatomic, assign) CLLocationCoordinate2D fakeCoords;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, assign) BOOL isJitterActive;
@property (nonatomic, assign) double jitterDistance;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *favorites;
@property (nonatomic, assign) BOOL hasStoredLocation;
@property (nonatomic, assign) double driftLatitude;
@property (nonatomic, assign) double driftLongitude;

// Route Simulation
@property (nonatomic, assign) BOOL isRouteActive;
@property (nonatomic, assign) CLLocationCoordinate2D startCoords;
@property (nonatomic, assign) CLLocationCoordinate2D endCoords;
@property (nonatomic, assign) double travelSpeed;
@property (nonatomic, assign) CLLocationCoordinate2D currentMovingCoords;
@property (nonatomic, assign) NSInteger mapType;

+ (instancetype)shared;
- (void)save;
- (void)load;
@end
