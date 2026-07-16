#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface WolfoxSpoofOverlay : UIViewController <MKMapViewDelegate, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate>
@property (nonatomic, strong) UIButton *gpsBtn;
@property (nonatomic, strong) UIVisualEffectView *panel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *controlsContainer;
@property (nonatomic, strong) MKMapView *map;
@property (nonatomic, strong) UIButton *expandMapBtn;
@property (nonatomic, strong) UISegmentedControl *mapTypeControl;
@property (nonatomic, strong) MKPointAnnotation *pin;
@property (nonatomic, strong) UISearchBar *searchBar;

// Favorites
@property (nonatomic, strong) UIVisualEffectView *favView;
@property (nonatomic, strong) UITableView *table;

// Bluetooth Scanner
@property (nonatomic, strong) UIVisualEffectView *btView;
@property (nonatomic, strong) UITableView *btTable;
@property (nonatomic, strong) UILabel *btStatusLabel;
@property (nonatomic, strong) CBCentralManager *cbManager;
@property (nonatomic, strong) NSMutableArray *discoveredDevices;

// Controls
@property (nonatomic, strong) UIButton *mainActionBtn;
@property (nonatomic, strong) UISwitch *jitterSwitch;
@property (nonatomic, strong) UISlider *jitterSlider;
@property (nonatomic, strong) UILabel *jitterLabel;

// Route Simulation UI
@property (nonatomic, assign) BOOL isRouteModeEnabled;
@property (nonatomic, strong) MKPointAnnotation *startPin;
@property (nonatomic, strong) MKPointAnnotation *endPin;
@property (nonatomic, strong) MKPolyline *routeLine;
@property (nonatomic, strong) UILabel *speedLabel;
@property (nonatomic, strong) NSTimer *routeTimer;

// Restart Modal
@property (nonatomic, strong) UIVisualEffectView *confirmDialogBackdrop;
@property (nonatomic, strong) UIView *confirmDialogView;
@property (nonatomic, strong) UILabel *timerLabel;
@property (nonatomic, assign) NSInteger countdownTimer;
@property (nonatomic, strong) NSTimer *restartTimer;
@property (nonatomic, assign) BOOL isPendingRestart;
@property (nonatomic, assign) BOOL isMapExpanded;

@property (nonatomic, strong) NSTimer *jitterTimer;
@property (nonatomic, assign) BOOL toolHidden;
@property (nonatomic, assign) CGFloat panelWidth;
@property (nonatomic, assign) CGFloat panelHeight;
@property (nonatomic, assign) CGFloat collapsedMapHeight;

+ (instancetype)shared;
- (void)hideToolCompletely;
- (void)showToolGesture;
void WolfoxEnableTool(void);
@end
