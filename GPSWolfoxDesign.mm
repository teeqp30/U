#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "GPSWolfoxAPI.h"
#import "WolfoxSpoofStore.h"
#import "Tweak.x"

static UIColor *WFColor(NSInteger rgb, CGFloat alpha) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF)/255.0
                           green:((rgb >> 8) & 0xFF)/255.0
                            blue:(rgb & 0xFF)/255.0 alpha:alpha];
}

static UIWindow *WFKeyWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class] || scene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) if (window.isKeyWindow) return window;
        }
    }
    return app.keyWindow ?: app.windows.firstObject;
}

static UIViewController *WFTopController(void) {
    UIViewController *vc = WFKeyWindow().rootViewController;
    while (vc) {
        if (vc.presentedViewController) { vc = vc.presentedViewController; continue; }
        if ([vc isKindOfClass:UINavigationController.class]) { vc = ((UINavigationController *)vc).visibleViewController; continue; }
        if ([vc isKindOfClass:UITabBarController.class]) { vc = ((UITabBarController *)vc).selectedViewController; continue; }
        break;
    }
    return vc;
}

#pragma mark - Activation UI

@interface WFActivationViewController : UIViewController <UITextFieldDelegate>
@property(nonatomic,strong) UITextField *codeField;
@property(nonatomic,strong) UIButton *activateButton;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) id requestObserver;
@end

@implementation WFActivationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    self.view.backgroundColor = WFColor(0x050710, 1.0);
    CGFloat screenHeight = UIScreen.mainScreen.bounds.size.height;
    CGFloat screenWidth = UIScreen.mainScreen.bounds.size.width;
    BOOL compactLayout = screenHeight < 700.0 || screenWidth < 360.0;
    CGFloat logoTop = compactLayout ? 38.0 : 75.0;
    CGFloat logoSize = compactLayout ? 78.0 : 96.0;
    CGFloat sideMargin = screenWidth < 340.0 ? 20.0 : (compactLayout ? 24.0 : 32.0);

    CAGradientLayer *bg = [CAGradientLayer layer];
    bg.colors = @[(id)WFColor(0x070A15,1).CGColor, (id)WFColor(0x110620,1).CGColor, (id)WFColor(0x02040A,1).CGColor];
    bg.startPoint = CGPointMake(0, 0); bg.endPoint = CGPointMake(1, 1);
    bg.frame = UIScreen.mainScreen.bounds;
    [self.view.layer insertSublayer:bg atIndex:0];

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    close.translatesAutoresizingMaskIntoConstraints = NO;
    [close setImage:[UIImage systemImageNamed:@"xmark"] forState:UIControlStateNormal];
    close.tintColor = UIColor.whiteColor;
    close.backgroundColor = WFColor(0x151A28, .9);
    close.layer.cornerRadius = 20;
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];

    UIView *logo = [UIView new];
    logo.translatesAutoresizingMaskIntoConstraints = NO;
    logo.backgroundColor = WFColor(0x7C2DFF, .18);
    logo.layer.cornerRadius = 48;
    logo.layer.borderWidth = 2;
    logo.layer.borderColor = WFColor(0xA855F7, .8).CGColor;
    logo.layer.shadowColor = WFColor(0x8B5CF6, 1).CGColor;
    logo.layer.shadowOpacity = .55;
    logo.layer.shadowRadius = 24;
    [self.view addSubview:logo];

    UIImageView *logoIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"location.fill"]];
    logoIcon.translatesAutoresizingMaskIntoConstraints = NO;
    logoIcon.tintColor = WFColor(0xB667FF,1);
    logoIcon.contentMode = UIViewContentModeScaleAspectFit;
    [logo addSubview:logoIcon];

    UILabel *title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"WOLFOX\nULTIMATE";
    title.numberOfLines = 2;
    title.textAlignment = NSTextAlignmentCenter;
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont systemFontOfSize:(compactLayout ? 24.0 : 29.0) weight:UIFontWeightBlack];
    [self.view addSubview:title];

    UILabel *sub = [UILabel new];
    sub.translatesAutoresizingMaskIntoConstraints = NO;
    sub.text = @"تفعيل الأداة";
    sub.textAlignment = NSTextAlignmentCenter;
    sub.textColor = WFColor(0xC084FC,1);
    sub.font = [UIFont systemFontOfSize:(compactLayout ? 18.0 : 21.0) weight:UIFontWeightBold];
    [self.view addSubview:sub];

    UILabel *hint = [UILabel new];
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    hint.text = @"أدخل كود التفعيل الخاص بك لفتح جميع المميزات";
    hint.numberOfLines = 0;
    hint.textAlignment = NSTextAlignmentCenter;
    hint.textColor = WFColor(0xA8AABC,1);
    hint.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    [self.view addSubview:hint];

    UIView *fieldBox = [UIView new];
    fieldBox.translatesAutoresizingMaskIntoConstraints = NO;
    fieldBox.backgroundColor = WFColor(0x111522,.92);
    fieldBox.layer.cornerRadius = 16;
    fieldBox.layer.borderWidth = 1;
    fieldBox.layer.borderColor = WFColor(0x343A50,.8).CGColor;
    [self.view addSubview:fieldBox];

    self.codeField = [UITextField new];
    self.codeField.translatesAutoresizingMaskIntoConstraints = NO;
    self.codeField.placeholder = @"WF-XXXX-XXXX";
    self.codeField.textColor = UIColor.whiteColor;
    self.codeField.font = [UIFont monospacedSystemFontOfSize:17 weight:UIFontWeightSemibold];
    self.codeField.textAlignment = NSTextAlignmentCenter;
    self.codeField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.codeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeField.returnKeyType = UIReturnKeyDone;
    self.codeField.delegate = self;
    [fieldBox addSubview:self.codeField];

    UIButton *paste = [UIButton buttonWithType:UIButtonTypeSystem];
    paste.translatesAutoresizingMaskIntoConstraints = NO;
    [paste setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
    paste.tintColor = WFColor(0xB667FF,1);
    [paste addTarget:self action:@selector(pasteCode) forControlEvents:UIControlEventTouchUpInside];
    [fieldBox addSubview:paste];

    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.activateButton setTitle:@"تفعيل" forState:UIControlStateNormal];
    [self.activateButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    self.activateButton.layer.cornerRadius = 16;
    [self.activateButton addTarget:self action:@selector(activateTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.activateButton];

    CAGradientLayer *buttonGradient = [CAGradientLayer layer];
    buttonGradient.name = @"wfButtonGradient";
    buttonGradient.colors = @[(id)WFColor(0xA855F7,1).CGColor,(id)WFColor(0x6D28D9,1).CGColor];
    buttonGradient.startPoint = CGPointMake(0, .5); buttonGradient.endPoint = CGPointMake(1, .5);
    buttonGradient.cornerRadius = 16;
    [self.activateButton.layer insertSublayer:buttonGradient atIndex:0];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = UIColor.whiteColor;
    self.spinner.hidesWhenStopped = YES;
    [self.activateButton addSubview:self.spinner];

    self.statusLabel = [UILabel new];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.textColor = WFColor(0x9CA3AF,1);
    self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.statusLabel.numberOfLines = 2;
    self.statusLabel.text = [NSString stringWithFormat:@"معرف الجهاز\n%@", GPSLicenseDeviceUUID() ?: @"—"];
    [self.view addSubview:self.statusLabel];

    UIButton *support = [UIButton buttonWithType:UIButtonTypeSystem];
    support.translatesAutoresizingMaskIntoConstraints = NO;
    [support setTitle:@"أين أحصل على كود؟" forState:UIControlStateNormal];
    [support setTitleColor:WFColor(0xC084FC,1) forState:UIControlStateNormal];
    support.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [support addTarget:self action:@selector(openSupport) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:support];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [close.topAnchor constraintEqualToAnchor:safe.topAnchor constant:14],
        [close.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-18],
        [close.widthAnchor constraintEqualToConstant:40], [close.heightAnchor constraintEqualToConstant:40],
        [logo.topAnchor constraintEqualToAnchor:safe.topAnchor constant:logoTop],
        [logo.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [logo.widthAnchor constraintEqualToConstant:logoSize], [logo.heightAnchor constraintEqualToConstant:logoSize],
        [logoIcon.centerXAnchor constraintEqualToAnchor:logo.centerXAnchor], [logoIcon.centerYAnchor constraintEqualToAnchor:logo.centerYAnchor],
        [logoIcon.widthAnchor constraintEqualToConstant:(compactLayout ? 36.0 : 44.0)], [logoIcon.heightAnchor constraintEqualToConstant:(compactLayout ? 36.0 : 44.0)],
        [title.topAnchor constraintEqualToAnchor:logo.bottomAnchor constant:(compactLayout ? 12.0 : 20.0)],
        [title.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [sub.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:(compactLayout ? 9.0 : 18.0)],
        [sub.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [hint.topAnchor constraintEqualToAnchor:sub.bottomAnchor constant:(compactLayout ? 8.0 : 14.0)],
        [hint.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:(compactLayout ? 24.0 : 44.0)],
        [hint.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:(compactLayout ? -24.0 : -44.0)],
        [fieldBox.topAnchor constraintEqualToAnchor:hint.bottomAnchor constant:(compactLayout ? 15.0 : 26.0)],
        [fieldBox.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:sideMargin],
        [fieldBox.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-sideMargin],
        [fieldBox.heightAnchor constraintEqualToConstant:(compactLayout ? 52.0 : 58.0)],
        [self.codeField.leadingAnchor constraintEqualToAnchor:fieldBox.leadingAnchor constant:44],
        [self.codeField.trailingAnchor constraintEqualToAnchor:paste.leadingAnchor constant:-6],
        [self.codeField.topAnchor constraintEqualToAnchor:fieldBox.topAnchor], [self.codeField.bottomAnchor constraintEqualToAnchor:fieldBox.bottomAnchor],
        [paste.trailingAnchor constraintEqualToAnchor:fieldBox.trailingAnchor constant:-14], [paste.centerYAnchor constraintEqualToAnchor:fieldBox.centerYAnchor],
        [paste.widthAnchor constraintEqualToConstant:30], [paste.heightAnchor constraintEqualToConstant:30],
        [self.activateButton.topAnchor constraintEqualToAnchor:fieldBox.bottomAnchor constant:(compactLayout ? 12.0 : 18.0)],
        [self.activateButton.leadingAnchor constraintEqualToAnchor:fieldBox.leadingAnchor],
        [self.activateButton.trailingAnchor constraintEqualToAnchor:fieldBox.trailingAnchor],
        [self.activateButton.heightAnchor constraintEqualToConstant:(compactLayout ? 50.0 : 56.0)],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.activateButton.centerYAnchor],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.activateButton.centerXAnchor constant:-45],
        [support.topAnchor constraintEqualToAnchor:self.activateButton.bottomAnchor constant:(compactLayout ? 9.0 : 16.0)], [support.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:support.bottomAnchor constant:(compactLayout ? 13.0 : 28.0)],
        [self.statusLabel.bottomAnchor constraintLessThanOrEqualToAnchor:safe.bottomAnchor constant:-8.0],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20]
    ]];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    for (CALayer *layer in self.activateButton.layer.sublayers) if ([layer.name isEqualToString:@"wfButtonGradient"]) layer.frame = self.activateButton.bounds;
}

- (void)closeTapped { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)pasteCode { self.codeField.text = UIPasteboard.generalPasteboard.string ?: @""; }
- (void)openSupport { NSURL *url=[NSURL URLWithString:GPSLicenseSupportURL() ?: @""]; if(url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil]; }
- (BOOL)textFieldShouldReturn:(UITextField *)textField { [self activateTapped]; return YES; }

- (void)activateTapped {
    NSString *code = [[self.codeField.text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] uppercaseString];
    if (!code.length) {
        self.statusLabel.text = @"أدخل كود التفعيل أولًا";
        self.statusLabel.textColor = UIColor.systemRedColor;
        return;
    }
    self.activateButton.enabled = NO;
    [self.spinner startAnimating];
    [self.activateButton setTitle:@"جاري التحقق..." forState:UIControlStateNormal];
    self.statusLabel.text = @"يتم الآن ربط الجهاز بالخادم";
    self.statusLabel.textColor = WFColor(0x9CA3AF,1);
    GPSLicenseActivateCode(code);

    // تُغلق الشاشة تلقائيًا بعد وصول إشعار نجاح التفعيل.
    [[NSNotificationCenter defaultCenter] addObserverForName:@"GPSLicenseAuthorizedNotification" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *n) {
        [self.spinner stopAnimating];
        [self.activateButton setTitle:@"تم التفعيل ✓" forState:UIControlStateNormal];
        self.statusLabel.text = [NSString stringWithFormat:@"تم التفعيل بنجاح\nالصلاحية: %@", GPSLicenseExpiresAt() ?: @"نشطة"];
        self.statusLabel.textColor = UIColor.systemGreenColor;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self dismissViewControllerAnimated:YES completion:nil]; });
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!GPSLicenseIsAuthorized()) {
            [self.spinner stopAnimating];
            self.activateButton.enabled = YES;
            [self.activateButton setTitle:@"تفعيل" forState:UIControlStateNormal];
        }
    });
}
@end

#pragma mark - Floating Orb

@interface WFFloatingWindow : UIWindow @end
@implementation WFFloatingWindow
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    UIView *v = [super hitTest:p withEvent:e];
    return (v == self || v == self.rootViewController.view) ? nil : v;
}
@end

@interface WFFloatingController : NSObject
@property(nonatomic,strong) WFFloatingWindow *window;
@property(nonatomic,strong) UIButton *orb;
@property(nonatomic,assign) CGPoint dragStart;
@property(nonatomic,assign) BOOL hiddenByUser;
+ (instancetype)shared;
- (void)show;
- (void)hide;
@end

@implementation WFFloatingController
+ (instancetype)shared { static id s; static dispatch_once_t once; dispatch_once(&once, ^{ s=[self new]; }); return s; }

- (void)buildIfNeeded {
    if (self.window) return;
    CGFloat savedY = [[NSUserDefaults standardUserDefaults] doubleForKey:@"WFOrbY"]; if (savedY <= 0) savedY = UIScreen.mainScreen.bounds.size.height*.43;
    BOOL savedLeft = [[NSUserDefaults standardUserDefaults] boolForKey:@"WFOrbLeft"];
    CGRect f = CGRectMake(savedLeft ? 6 : UIScreen.mainScreen.bounds.size.width-72, savedY, 66, 66);
    self.window = [[WFFloatingWindow alloc] initWithFrame:f];
    self.window.windowLevel = UIWindowLevelAlert + 120;
    self.window.backgroundColor = UIColor.clearColor;
    self.window.rootViewController = [UIViewController new];
    self.window.rootViewController.view.backgroundColor = UIColor.clearColor;

    self.orb = [UIButton buttonWithType:UIButtonTypeCustom];
    self.orb.frame = self.window.bounds;
    self.orb.layer.cornerRadius = 33;
    self.orb.backgroundColor = WFColor(0x170C2D,.96);
    self.orb.layer.borderWidth = 2;
    self.orb.layer.borderColor = WFColor(0x9B4DFF,1).CGColor;
    self.orb.layer.shadowColor = WFColor(0x8B5CF6,1).CGColor;
    self.orb.layer.shadowOpacity = .9;
    self.orb.layer.shadowRadius = 14;
    self.orb.layer.shadowOffset = CGSizeZero;
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:27 weight:UIImageSymbolWeightBold];
    [self.orb setImage:[[UIImage systemImageNamed:@"location.fill" withConfiguration:cfg] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    self.orb.tintColor = WFColor(0xC084FC,1);
    [self.orb addTarget:self action:@selector(tapOrb) forControlEvents:UIControlEventTouchUpInside];
    [self.orb addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragOrb:)]];
    [self.orb addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)]];
    [self.window.rootViewController.view addSubview:self.orb];

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
    pulse.fromValue = @8; pulse.toValue = @20; pulse.duration = 1.35; pulse.autoreverses = YES; pulse.repeatCount = HUGE_VALF;
    [self.orb.layer addAnimation:pulse forKey:@"wfPulse"];

    [self installRevealGesture];
}

- (void)installRevealGesture {
    UIWindow *host = WFKeyWindow();
    if (!host || [host viewWithTag:779911]) return;
    UIView *edge = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 18, host.bounds.size.height)];
    edge.tag = 779911; edge.backgroundColor = UIColor.clearColor;
    edge.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    UIScreenEdgePanGestureRecognizer *g = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(edgeReveal:)];
    g.edges = UIRectEdgeLeft; [edge addGestureRecognizer:g];
    [host addSubview:edge];
}

- (void)show { [self buildIfNeeded]; self.hiddenByUser = NO; [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WFOrbHidden"]; self.window.hidden = NO; }
- (void)hide { self.hiddenByUser = YES; [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WFOrbHidden"]; self.window.hidden = YES; }
- (void)tapOrb { if (GPSLicenseIsAuthorized()) WolfoxToggleMainPanel(); else GPSLicensePresentActivation(); }
- (void)longPress:(UILongPressGestureRecognizer *)g { if (g.state == UIGestureRecognizerStateBegan) [self hide]; }

- (void)dragOrb:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:nil];
    CGRect f = self.window.frame; f.origin.x += t.x; f.origin.y += t.y;
    CGFloat maxX = UIScreen.mainScreen.bounds.size.width - f.size.width;
    CGFloat maxY = UIScreen.mainScreen.bounds.size.height - f.size.height - 20;
    f.origin.x = MAX(0, MIN(maxX, f.origin.x)); f.origin.y = MAX(40, MIN(maxY, f.origin.y));
    self.window.frame = f; [g setTranslation:CGPointZero inView:nil];
    if (g.state == UIGestureRecognizerStateEnded) {
        BOOL left = CGRectGetMidX(f) < UIScreen.mainScreen.bounds.size.width/2;
        f.origin.x = left ? 6 : UIScreen.mainScreen.bounds.size.width-f.size.width-6;
        [[NSUserDefaults standardUserDefaults] setBool:left forKey:@"WFOrbLeft"];
        [[NSUserDefaults standardUserDefaults] setDouble:f.origin.y forKey:@"WFOrbY"];
        [UIView animateWithDuration:.25 delay:0 usingSpringWithDamping:.75 initialSpringVelocity:.4 options:0 animations:^{ self.window.frame=f; } completion:nil];
    }
}

- (void)edgeReveal:(UIScreenEdgePanGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateEnded && [g translationInView:g.view].x > 55) [self show];
}
@end

extern "C" void GPSLicensePresentActivation(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *top = WFTopController();
        if (!top || [top isKindOfClass:WFActivationViewController.class] || [top.presentedViewController isKindOfClass:WFActivationViewController.class]) return;
        WFActivationViewController *vc = [WFActivationViewController new];
        vc.modalPresentationStyle = UIModalPresentationFullScreen;
        [top presentViewController:vc animated:YES completion:nil];
    });
}

extern "C" void GPSFloatingIconShow(void) { dispatch_async(dispatch_get_main_queue(), ^{ [[WFFloatingController shared] show]; }); }
extern "C" void GPSFloatingIconHide(void) { dispatch_async(dispatch_get_main_queue(), ^{ [[WFFloatingController shared] hide]; }); }

__attribute__((constructor)) static void WFDesignInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:@"GPSLicenseAuthorizedNotification" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *n){
            if (![[WolfoxSpoofStore shared] toolHidden]) {
                GPSFloatingIconShow();
            }
        }];
        [[NSNotificationCenter defaultCenter] addObserverForName:@"GPSLicenseRevokedNotification" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *n){ GPSFloatingIconHide(); GPSLicensePresentActivation(); }];
        if (GPSLicenseIsAuthorized() && ![[WolfoxSpoofStore shared] toolHidden]) GPSFloatingIconShow();
    });
}
