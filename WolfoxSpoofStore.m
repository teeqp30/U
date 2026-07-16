#import "WolfoxSpoofStore.h"

@implementation WolfoxSpoofStore

+ (instancetype)shared {
    static WolfoxSpoofStore *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[WolfoxSpoofStore alloc] init]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _favorites    = [NSMutableArray array];
        _jitterDistance = 10.0;
        _hideClickCount = 3;
        _mapType = 0;
        [self load];
    }
    return self;
}

- (NSString *)getDeviceUUID {
    NSString *uuid = [[NSUserDefaults standardUserDefaults] stringForKey:@"WolfGps_UUID"];
    if (!uuid || uuid.length == 0) {
        uuid = [[[NSUUID UUID] UUIDString] lowercaseString];
        [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:@"WolfGps_UUID"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return uuid;
}

- (void)save {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    [u setDouble:self.fakeCoords.latitude  forKey:@"WolfGps_LAT"];
    [u setDouble:self.fakeCoords.longitude forKey:@"WolfGps_LON"];
    [u setBool:self.isActive               forKey:@"WolfGps_ACTIVE"];
    [u setBool:self.hasStoredLocation      forKey:@"WolfGps_HAS_LOC"];
    [u setBool:self.isJitterActive         forKey:@"WolfGps_JITTER"];
    [u setDouble:self.jitterDistance       forKey:@"WolfGps_JITTER_DIST"];
    [u setDouble:self.driftLatitude        forKey:@"WolfGps_DRIFT_LAT"];
    [u setDouble:self.driftLongitude       forKey:@"WolfGps_DRIFT_LON"];
    [u setObject:self.favorites            forKey:@"WolfGps_FAVS"];
    [u setBool:self.toolHidden             forKey:@"WolfGps_HIDDEN"];
    [u setBool:self.isPermanentlyHidden    forKey:@"WolfGps_PERM_HIDDEN"];
    [u setInteger:self.hideClickCount      forKey:@"WolfGps_HIDE_COUNT"];
    [u setBool:self.cameraSimEnabled       forKey:@"WolfGps_CAM_SIM"];
    [u setObject:self.activationCode ?: @"" forKey:@"WolfGps_ACT_CODE"];
    [u setBool:self.isActivated            forKey:@"WolfGps_ACTIVATED"];
    [u setObject:self.expiresAt ?: @""     forKey:@"WolfGps_EXPIRES"];
    [u setInteger:self.mapType             forKey:@"WolfGps_MAP_TYPE"];
    [u synchronize];
}

- (void)load {
    NSUserDefaults *u = [NSUserDefaults standardUserDefaults];
    _isActive           = [u boolForKey:@"WolfGps_ACTIVE"];
    _hasStoredLocation  = [u boolForKey:@"WolfGps_HAS_LOC"];
    _isJitterActive     = [u boolForKey:@"WolfGps_JITTER"];
    _jitterDistance     = [u doubleForKey:@"WolfGps_JITTER_DIST"] ?: 10.0;
    _driftLatitude      = [u doubleForKey:@"WolfGps_DRIFT_LAT"];
    _driftLongitude     = [u doubleForKey:@"WolfGps_DRIFT_LON"];
    _toolHidden         = [u boolForKey:@"WolfGps_HIDDEN"];
    _isPermanentlyHidden = [u boolForKey:@"WolfGps_PERM_HIDDEN"];
    _hideClickCount     = [u integerForKey:@"WolfGps_HIDE_COUNT"] ?: 3;
    _cameraSimEnabled   = [u boolForKey:@"WolfGps_CAM_SIM"];
    _activationCode     = [u stringForKey:@"WolfGps_ACT_CODE"] ?: @"";
    _isActivated        = [u boolForKey:@"WolfGps_ACTIVATED"];
    _expiresAt          = [u stringForKey:@"WolfGps_EXPIRES"] ?: @"";
    _mapType            = [u integerForKey:@"WolfGps_MAP_TYPE"];
    NSArray *favs = [u arrayForKey:@"WolfGps_FAVS"];
    _favorites = favs ? [favs mutableCopy] : [NSMutableArray array];
    if (_hasStoredLocation) {
        _fakeCoords = CLLocationCoordinate2DMake([u doubleForKey:@"WolfGps_LAT"], [u doubleForKey:@"WolfGps_LON"]);
    } else {
        _fakeCoords = CLLocationCoordinate2DMake(24.7136, 46.6753);
    }
    _deviceUUID = [self getDeviceUUID];
}

@end
