#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "WolfoxSpoofStore.h"
#import "WolfoxSpoofOverlay.h"
#import <substrate.h>

// ============================================================
//  الأيقونة العائمة لـ Wolf Gps
// ============================================================

@interface WolfGpsFloatingButton : UIWindow
@property (nonatomic, strong) UIButton *iconBtn;
@property (nonatomic, strong) CAShapeLayer *pulseLayer;
@property (nonatomic, assign) NSInteger tapCount;
@property (nonatomic, strong) NSTimer *tapTimer;
@property (nonatomic, strong) WolfoxSpoofOverlay *overlay;
@property (nonatomic, strong) UIWindow *overlayWindow;
@end

@implementation WolfGpsFloatingButton

- (instancetype)init {
    if (self = [super initWithFrame:CGRectMake(20, 120, 56, 56)]) {
        self.windowLevel = UIWindowLevelAlert + 100;
        self.backgroundColor = [UIColor clearColor];
        self.layer.cornerRadius = 28;
        self.clipsToBounds = NO;
        [self buildIcon];
        [self setupVolumeObserver];
        [self startPulseAnimation];
        [self updateIconColor];
        self.hidden = [WolfoxSpoofStore shared].isPermanentlyHidden;
        [self makeKeyAndVisible];
    }
    return self;
}

- (void)buildIcon {
    // طبقة النبض
    _pulseLayer = [CAShapeLayer layer];
    _pulseLayer.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(-4, -4, 64, 64)].CGPath;
    _pulseLayer.fillColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:0.3].CGColor;
    _pulseLayer.strokeColor = [UIColor clearColor].CGColor;
    [self.layer addSublayer:_pulseLayer];

    // الزر الرئيسي
    _iconBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _iconBtn.frame = CGRectMake(0, 0, 56, 56);
    _iconBtn.layer.cornerRadius = 28;
    _iconBtn.clipsToBounds = YES;
    _iconBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    _iconBtn.layer.shadowOffset = CGSizeMake(0, 3);
    _iconBtn.layer.shadowOpacity = 0.4;
    _iconBtn.layer.shadowRadius = 6;
    [_iconBtn setTitle:@"🐺" forState:UIControlStateNormal];
    _iconBtn.titleLabel.font = [UIFont systemFontOfSize:28];
    [_iconBtn addTarget:self action:@selector(iconTapped) forControlEvents:UIControlEventTouchUpInside];

    // سحب الأيقونة
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_iconBtn addGestureRecognizer:pan];

    [self addSubview:_iconBtn];
}

- (void)updateIconColor {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    UIColor *bg = store.isActive
        ? [UIColor colorWithRed:0.05 green:0.6 blue:0.15 alpha:1.0]
        : [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    _iconBtn.backgroundColor = bg;
    _pulseLayer.fillColor = store.isActive
        ? [UIColor colorWithRed:0.1 green:0.8 blue:0.2 alpha:0.25].CGColor
        : [UIColor colorWithWhite:0.5 alpha:0.1].CGColor;
}

- (void)startPulseAnimation {
    CABasicAnimation *scale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    scale.fromValue = @1.0;
    scale.toValue = @1.3;
    scale.duration = 1.2;
    scale.autoreverses = YES;
    scale.repeatCount = HUGE_VALF;
    scale.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_pulseLayer addAnimation:scale forKey:@"pulse"];

    // تحريك الأيقونة بشكل دوري
    CAKeyframeAnimation *wobble = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation"];
    wobble.values = @[@(-0.05), @(0.05), @(-0.05)];
    wobble.duration = 2.5;
    wobble.repeatCount = HUGE_VALF;
    [_iconBtn.layer addAnimation:wobble forKey:@"wobble"];
}

- (void)iconTapped {
    _tapCount++;
    [_tapTimer invalidate];
    _tapTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(processTaps) userInfo:nil repeats:NO];
}

- (void)processTaps {
    NSInteger required = [WolfoxSpoofStore shared].hideClickCount;
    if (_tapCount >= required) {
        [self showOverlay];
    }
    _tapCount = 0;
}

- (void)showOverlay {
    if (_overlayWindow) { [_overlayWindow makeKeyAndVisible]; return; }
    UIScreen *screen = [UIScreen mainScreen];
    _overlayWindow = [[UIWindow alloc] initWithFrame:screen.bounds];
    _overlayWindow.windowLevel = UIWindowLevelAlert + 50;
    _overlayWindow.backgroundColor = [UIColor clearColor];

    _overlay = [[WolfoxSpoofOverlay alloc] initWithFrame:screen.bounds];
    _overlayWindow.rootViewController = [[UIViewController alloc] init];
    _overlayWindow.rootViewController.view = _overlay;
    [_overlayWindow makeKeyAndVisible];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    CGPoint delta = [pan translationInView:self];
    CGRect frame = self.frame;
    frame.origin.x += delta.x;
    frame.origin.y += delta.y;
    // حدود الشاشة
    CGFloat maxX = [UIScreen mainScreen].bounds.size.width - 56;
    CGFloat maxY = [UIScreen mainScreen].bounds.size.height - 56;
    frame.origin.x = MAX(0, MIN(frame.origin.x, maxX));
    frame.origin.y = MAX(20, MIN(frame.origin.y, maxY));
    self.frame = frame;
    [pan setTranslation:CGPointZero inView:self];
}

// ============================================================
//  نظام الإخفاء عبر زر رفع الصوت
// ============================================================
- (void)setupVolumeObserver {
    // مراقبة تغيير الصوت
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(volumeChanged:) name:@"AVSystemController_SystemVolumeDidChangeNotification" object:nil];
}

static NSInteger _volumeUpCount = 0;
static NSDate *_lastVolumeTime = nil;

- (void)volumeChanged:(NSNotification *)notif {
    NSDictionary *info = notif.userInfo;
    NSString *reason = info[@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"];
    if (![reason isEqualToString:@"ExplicitVolumeChange"]) return;

    float vol = [info[@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
    static float lastVol = 0.5;
    BOOL isUp = (vol > lastVol);
    lastVol = vol;

    if (!isUp) { _volumeUpCount = 0; return; }

    NSDate *now = [NSDate date];
    if (_lastVolumeTime && [now timeIntervalSinceDate:_lastVolumeTime] > 1.5) {
        _volumeUpCount = 0;
    }
    _lastVolumeTime = now;
    _volumeUpCount++;

    if (_volumeUpCount >= 2) {
        _volumeUpCount = 0;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self toggleVisibility];
        });
    }
}

- (void)toggleVisibility {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    BOOL newHidden = !self.hidden;
    self.hidden = newHidden;
    store.isPermanentlyHidden = newHidden;
    store.toolHidden = newHidden;
    [store save];
}

@end

// ============================================================
//  الأداة الرئيسية - Wolf Gps
// ============================================================

static WolfGpsFloatingButton *wolfButton = nil;

void WolfGpsInitUI(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!wolfButton) {
            wolfButton = [[WolfGpsFloatingButton alloc] init];
        }
    });
}
