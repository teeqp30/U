#import "WolfoxSpoofStore.h"
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@implementation WolfoxSpoofStore
+ (instancetype)shared {
    static WolfoxSpoofStore *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[WolfoxSpoofStore alloc] init]; });
    return s;
}
- (instancetype)init {
    if (self = [super init]) {
        _favorites = [NSMutableArray array];
        _driftLatitude = 0.0; _driftLongitude = 0.0; _jitterDistance = 10.0;
        _travelSpeed = 20.0;
        [self load];
    }
    return self;
}
- (void)save {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    [u setDouble:self.fakeCoords.latitude forKey:@"WolfoxSpoof_LAT_S"];
    [u setDouble:self.fakeCoords.longitude forKey:@"WolfoxSpoof_LON_S"];
    [u setBool:self.isActive forKey:@"WolfoxSpoof_ACTIVE_S"];
    [u setBool:self.isJitterActive forKey:@"WolfoxSpoof_JITTER_S"];
    [u setDouble:self.jitterDistance forKey:@"WolfoxSpoof_JITTER_DIST"];
    [u setObject:self.favorites forKey:@"WolfoxSpoof_FAVS_S"];
    [u setBool:self.hasStoredLocation forKey:@"WolfoxSpoof_HAS_LOC"];
    [u setDouble:self.driftLatitude forKey:@"WolfoxSpoof_DRIFT_LAT"];
    [u setDouble:self.driftLongitude forKey:@"WolfoxSpoof_DRIFT_LON"];
    [u setBool:self.toolHidden forKey:@"WolfoxSpoof_TOOL_HIDDEN"];

    // Route Simulation
    [u setBool:self.isRouteActive forKey:@"WolfoxSpoof_ROUTE_ACTIVE"];
    [u setDouble:self.startCoords.latitude forKey:@"WolfoxSpoof_ROUTE_START_LAT"];
    [u setDouble:self.startCoords.longitude forKey:@"WolfoxSpoof_ROUTE_START_LON"];
    [u setDouble:self.endCoords.latitude forKey:@"WolfoxSpoof_ROUTE_END_LAT"];
    [u setDouble:self.endCoords.longitude forKey:@"WolfoxSpoof_ROUTE_END_LON"];
    [u setDouble:self.travelSpeed forKey:@"WolfoxSpoof_ROUTE_SPEED"];
    [u setDouble:self.currentMovingCoords.latitude forKey:@"WolfoxSpoof_ROUTE_CURRENT_LAT"];
    [u setDouble:self.currentMovingCoords.longitude forKey:@"WolfoxSpoof_ROUTE_CURRENT_LON"];

    [u synchronize];
}
- (void)load {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    _fakeCoords.latitude = [u doubleForKey:@"WolfoxSpoof_LAT_S"];
    _fakeCoords.longitude = [u doubleForKey:@"WolfoxSpoof_LON_S"];
    _isActive = [u boolForKey:@"WolfoxSpoof_ACTIVE_S"];
    _isJitterActive = [u boolForKey:@"WolfoxSpoof_JITTER_S"];
    _jitterDistance = [u doubleForKey:@"WolfoxSpoof_JITTER_DIST"];
    NSArray *favs = [u arrayForKey:@"WolfoxSpoof_FAVS_S"];
    if (favs) _favorites = [favs mutableCopy];
    _hasStoredLocation = [u boolForKey:@"WolfoxSpoof_HAS_LOC"];
    _driftLatitude = [u doubleForKey:@"WolfoxSpoof_DRIFT_LAT"];
    _driftLongitude = [u doubleForKey:@"WolfoxSpoof_DRIFT_LON"];
    _toolHidden = [u boolForKey:@"WolfoxSpoof_TOOL_HIDDEN"];

    // Route Simulation
    _isRouteActive = [u boolForKey:@"WolfoxSpoof_ROUTE_ACTIVE"];
    _startCoords.latitude = [u doubleForKey:@"WolfoxSpoof_ROUTE_START_LAT"];
    _startCoords.longitude = [u doubleForKey:@"WolfoxSpoof_ROUTE_START_LON"];
    _endCoords.latitude = [u doubleForKey:@"WolfoxSpoof_ROUTE_END_LAT"];
    _endCoords.longitude = [u doubleForKey:@"WolfoxSpoof_ROUTE_END_LON"];
    _travelSpeed = [u doubleForKey:@"WolfoxSpoof_ROUTE_SPEED"];
    _currentMovingCoords.latitude = [u doubleForKey:@"WolfoxSpoof_ROUTE_CURRENT_LAT"];
    _currentMovingCoords.longitude = [u doubleForKey:@"WolfoxSpoof_ROUTE_CURRENT_LON"];
}
@end
