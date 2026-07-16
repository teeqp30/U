#import "WolfoxSpoofOverlay.h"
#import "WolfoxSpoofStore.h"
#import "GPSWolfoxAPI.h"
#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreLocation/CoreLocation.h>

@implementation WolfoxSpoofOverlay

+ (instancetype)shared {
    static WolfoxSpoofOverlay *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[WolfoxSpoofOverlay alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.view.backgroundColor = [UIColor clearColor];
        self.view.userInteractionEnabled = YES;
        self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _toolHidden = [WolfoxSpoofStore shared].toolHidden;
        _isMapExpanded = NO;
        _isRouteModeEnabled = NO;
        _discoveredDevices = [NSMutableArray new];
        [self buildUI];
        _jitterTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tickJitter) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)buildUI {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIEdgeInsets safeAreaInsets = keyWindow.safeAreaInsets;
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    CGFloat pW = self.view.bounds.size.width - safeAreaInsets.left - safeAreaInsets.right;
    CGFloat pH = self.view.bounds.size.height - safeAreaInsets.top - safeAreaInsets.bottom;
    
    // Set _panel frame to full screen, respecting safe area
    _panel = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    _panel.frame = CGRectMake(safeAreaInsets.left, safeAreaInsets.top, pW, pH);
    _panel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _panel.layer.cornerRadius = 20;
    _panel.clipsToBounds = YES;
    [self.view addSubview:_panel];

    // Close Button
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(pW - 50, 10, 40, 40); // Top right corner within the panel
    closeBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.6];
    closeBtn.layer.cornerRadius = 20;
    [closeBtn setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    closeBtn.tintColor = [UIColor whiteColor];
    [closeBtn addTarget:self action:@selector(hideToolCompletely) forControlEvents:UIControlEventTouchUpInside];
    [_panel.contentView addSubview:closeBtn];

    // Header (adjusting for close button and full screen)
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, pW, 60)]; // Reduced header height
    [_panel.contentView addSubview:header];
    
    CGFloat logoSize = 40.0;
    UIImageView *logo = [[UIImageView alloc] initWithFrame:CGRectMake(pW-logoSize-15.0, 10.0, logoSize, logoSize)];
    logo.image = [UIImage systemImageNamed:@"location.north.circle.fill"];
    logo.tintColor = [UIColor systemGreenColor];
    [header addSubview:logo];

    // Add Subscription Info Button
    UIButton *subscriptionInfoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    subscriptionInfoBtn.frame = CGRectMake(15, 10, 150, 40); // Adjust position as needed
    [subscriptionInfoBtn setTitle:@"معلومات الاشتراك" forState:UIControlStateNormal];
    [subscriptionInfoBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    subscriptionInfoBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.6];
    subscriptionInfoBtn.layer.cornerRadius = 10;
    [subscriptionInfoBtn addTarget:self action:@selector(showSubscriptionInfo) forControlEvents:UIControlEventTouchUpInside];
    [_panel.contentView addSubview:subscriptionInfoBtn];

    // Map View
    _map = [[MKMapView alloc] initWithFrame:CGRectMake(0, 60, pW, pH - 60 - 150)]; // Adjust height for controls
    _map.delegate = self;
    _map.showsUserLocation = YES;
    _map.mapType = MKMapTypeStandard;
    _map.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_panel.contentView addSubview:_map];

    // Controls Container
    _controlsContainer = [[UIView alloc] initWithFrame:CGRectMake(0, pH - 150, pW, 150)];
    _controlsContainer.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7];
    _controlsContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_panel.contentView addSubview:_controlsContainer];

    // Map Type Control (Mixed)
    _mapTypeControl = [[UISegmentedControl alloc] initWithItems:@[@"عادي", @"قمر صناعي", @"مختلط"]];
    _mapTypeControl.frame = CGRectMake(10, 10, pW - 20, 30);
    _mapTypeControl.selectedSegmentIndex = 0;
    [_mapTypeControl addTarget:self action:@selector(mapTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [_controlsContainer addSubview:_mapTypeControl];

    // Current Location Button
    UIButton *currentLocationBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    currentLocationBtn.frame = CGRectMake(10, 50, (pW - 30) / 2, 40);
    [currentLocationBtn setTitle:@"موقعي الحالي" forState:UIControlStateNormal];
    [currentLocationBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    currentLocationBtn.backgroundColor = [UIColor systemBlueColor];
    currentLocationBtn.layer.cornerRadius = 10;
    [currentLocationBtn addTarget:self action:@selector(moveToCurrentLocation) forControlEvents:UIControlEventTouchUpInside];
    [_controlsContainer addSubview:currentLocationBtn];

    // Spoof Location Button
    _mainActionBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _mainActionBtn.frame = CGRectMake((pW - 30) / 2 + 20, 50, (pW - 30) / 2, 40);
    [_mainActionBtn setTitle:@"تزييف الموقع" forState:UIControlStateNormal];
    [_mainActionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _mainActionBtn.backgroundColor = [UIColor systemGreenColor];
    _mainActionBtn.layer.cornerRadius = 10;
    [_mainActionBtn addTarget:self action:@selector(toggleSpoofing) forControlEvents:UIControlEventTouchUpInside];
    [_controlsContainer addSubview:_mainActionBtn];

    // Jitter Switch and Slider (example, adjust as needed)
    _jitterSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(10, 100, 50, 30)];
    [_jitterSwitch addTarget:self action:@selector(jitterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [_controlsContainer addSubview:_jitterSwitch];

    _jitterLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 100, 100, 30)];
    _jitterLabel.text = @"Jitter";
    _jitterLabel.textColor = [UIColor whiteColor];
    [_controlsContainer addSubview:_jitterLabel];

    _jitterSlider = [[UISlider alloc] initWithFrame:CGRectMake(180, 100, pW - 190, 30)];
    _jitterSlider.minimumValue = 0;
    _jitterSlider.maximumValue = 100;
    [_jitterSlider addTarget:self action:@selector(jitterSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [_controlsContainer addSubview:_jitterSlider];

    // Initialize pin
    _pin = [[MKPointAnnotation alloc] init];
    [_map addAnnotation:_pin];

    // Update UI based on stored state
    [self updateUI];
}

- (void)updateUI {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    _jitterSwitch.on = store.isJitterActive;
    _jitterSlider.value = store.jitterDistance;
    _map.mapType = store.mapType;
    if (store.isActive) {
        [_mainActionBtn setTitle:@"إيقاف التزييف" forState:UIControlStateNormal];
        _mainActionBtn.backgroundColor = [UIColor systemRedColor];
    } else {
        [_mainActionBtn setTitle:@"تزييف الموقع" forState:UIControlStateNormal];
        _mainActionBtn.backgroundColor = [UIColor systemGreenColor];
    }
    if (store.hasStoredLocation) {
        _pin.coordinate = store.fakeCoords;
        [_map setCenterCoordinate:store.fakeCoords animated:YES];
    }
}

- (void)mapTypeChanged:(UISegmentedControl *)sender {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    switch (sender.selectedSegmentIndex) {
        case 0:
            _map.mapType = MKMapTypeStandard;
            store.mapType = MKMapTypeStandard;
            break;
        case 1:
            _map.mapType = MKMapTypeSatellite;
            store.mapType = MKMapTypeSatellite;
            break;
        case 2:
            _map.mapType = MKMapTypeHybrid;
            store.mapType = MKMapTypeHybrid;
            break;
    }
    [store save];
}

- (void)moveToCurrentLocation {
    if (_map.userLocation.location) {
        [_map setCenterCoordinate:_map.userLocation.location.coordinate animated:YES];
        _pin.coordinate = _map.userLocation.location.coordinate;
        WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
        store.fakeCoords = _map.userLocation.location.coordinate;
        store.hasStoredLocation = YES;
        [store save];
    }
}

- (void)toggleSpoofing {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    store.isActive = !store.isActive;
    [store save];
    [self updateUI];
}

- (void)jitterSwitchChanged:(UISwitch *)sender {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    store.isJitterActive = sender.on;
    [store save];
}

- (void)jitterSliderChanged:(UISlider *)sender {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    store.jitterDistance = sender.value;
    _jitterLabel.text = [NSString stringWithFormat:@"Jitter: %.1f", sender.value];
    [store save];
}

- (void)mapView:(MKMapView *)mapView regionDidChangeAnimated:(BOOL)animated {
    if (!_isMapExpanded) {
        _pin.coordinate = mapView.centerCoordinate;
        WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
        store.fakeCoords = mapView.centerCoordinate;
        store.hasStoredLocation = YES;
        [store save];
    }
}

- (void)showSubscriptionInfo {
    NSString *expiresAt = GPSLicenseExpiresAt() ?: @"غير متوفر";
    NSString *message = [NSString stringWithFormat:@"تاريخ انتهاء الاشتراك: %@", expiresAt];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"معلومات الاشتراك" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"موافق" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)hideToolCompletely {
    self.view.hidden = YES;
    [WolfoxSpoofStore shared].toolHidden = YES;
    [[WolfoxSpoofStore shared] save];
}

- (void)showToolGesture {
    self.view.hidden = NO;
    [WolfoxSpoofStore shared].toolHidden = NO;
    [[WolfoxSpoofStore shared] save];
}

@end

static UIWindow *wolfox_overlayWindow = nil;

void WolfoxToggleMainPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        WolfoxSpoofOverlay *overlay = [WolfoxSpoofOverlay shared];
        if (!GPSLicenseIsAuthorized()) { GPSLicensePresentActivation(); return; }
        if (overlay.view.hidden || !overlay.view.superview) {
            WolfoxEnableTool();
        } else {
            overlay.view.hidden = YES;
            [[WolfoxSpoofStore shared] setToolHidden:YES];
            [[WolfoxSpoofStore shared] save];
        }
    });
}

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

void WolfoxEnableTool(void) {
    if (!GPSLicenseIsAuthorized()) return;
    // wolfoxHooksInstalled check and setup removed as hooks are now set up in init_tool
    UIWindow *win = WolfoxCurrentWindow();
    if (!win) return;
    if ([WolfoxSpoofOverlay shared].view.superview != win) {
        [[WolfoxSpoofOverlay shared].view removeFromSuperview];
        [win addSubview:[WolfoxSpoofOverlay shared].view];
    }
    [WolfoxSpoofOverlay shared].view.hidden = NO;
}

#pragma mark - Protocol Stubs to fix build errors
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return 0; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath { return [UITableViewCell new]; }
- (void)centralManagerDidUpdateState:(CBCentralManager *)central { }
