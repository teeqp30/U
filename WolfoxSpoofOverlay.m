#import "WolfoxSpoofOverlay.h"
#import "WolfoxSpoofStore.h"
#import "GPSApiLocal.h"

@interface WolfoxSpoofOverlay ()
@property (nonatomic, strong) NSMutableArray *favData;
@property (nonatomic, strong) UIView *mainPanel;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *coordsLabel;
@property (nonatomic, assign) BOOL panelVisible;
@end

@implementation WolfoxSpoofOverlay

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = YES;
        [self buildUI];
        [self loadFavorites];
    }
    return self;
}

- (void)buildUI {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat W = screen.bounds.size.width;
    CGFloat H = screen.bounds.size.height;

    // لوحة رئيسية
    _mainPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
    _mainPanel.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.96];
    _mainPanel.layer.cornerRadius = 0;
    [self addSubview:_mainPanel];

    // شريط العنوان
    UIView *titleBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, W, 56)];
    titleBar.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:1.0];
    [_mainPanel addSubview:titleBar];

    // أيقونة الذئب
    UILabel *wolfIcon = [[UILabel alloc] initWithFrame:CGRectMake(16, 10, 36, 36)];
    wolfIcon.text = @"🐺";
    wolfIcon.font = [UIFont systemFontOfSize:28];
    wolfIcon.textAlignment = NSTextAlignmentCenter;
    [titleBar addSubview:wolfIcon];

    // اسم الأداة
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(58, 10, 180, 36)];
    _titleLabel.text = @"Wolf Gps";
    _titleLabel.font = [UIFont boldSystemFontOfSize:20];
    _titleLabel.textColor = [UIColor whiteColor];
    [titleBar addSubview:_titleLabel];

    // زر معلومات الاشتراك
    _infoBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _infoBtn.frame = CGRectMake(W - 100, 10, 36, 36);
    [_infoBtn setTitle:@"ℹ️" forState:UIControlStateNormal];
    _infoBtn.titleLabel.font = [UIFont systemFontOfSize:22];
    [_infoBtn addTarget:self action:@selector(showSubscriptionInfo) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:_infoBtn];

    // زر الإغلاق
    _closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _closeBtn.frame = CGRectMake(W - 52, 10, 36, 36);
    [_closeBtn setTitle:@"✕" forState:UIControlStateNormal];
    [_closeBtn setTitleColor:[UIColor colorWithRed:1 green:0.3 blue:0.3 alpha:1] forState:UIControlStateNormal];
    _closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [_closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [titleBar addSubview:_closeBtn];

    CGFloat y = 66;

    // حقل البحث
    UIView *searchContainer = [[UIView alloc] initWithFrame:CGRectMake(12, y, W - 24, 44)];
    searchContainer.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    searchContainer.layer.cornerRadius = 10;
    [_mainPanel addSubview:searchContainer];

    UILabel *searchIcon = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 24, 24)];
    searchIcon.text = @"🔍";
    searchIcon.font = [UIFont systemFontOfSize:16];
    [searchContainer addSubview:searchIcon];

    _searchField = [[UITextField alloc] initWithFrame:CGRectMake(40, 6, W - 90, 32)];
    _searchField.placeholder = @"ابحث عن موقع...";
    _searchField.textColor = [UIColor whiteColor];
    _searchField.font = [UIFont systemFontOfSize:15];
    _searchField.keyboardType = UIKeyboardTypeDefault;
    _searchField.returnKeyType = UIReturnKeySearch;
    _searchField.delegate = self;
    _searchField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"ابحث عن موقع..." attributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:0.5 alpha:1]}];
    [searchContainer addSubview:_searchField];

    y += 54;

    // إحداثيات الموقع الحالي
    _coordsLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, y, W - 24, 30)];
    _coordsLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    _coordsLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    _coordsLabel.textAlignment = NSTextAlignmentCenter;
    [self updateCoordsLabel];
    [_mainPanel addSubview:_coordsLabel];

    y += 34;

    // أزرار الخريطة
    NSArray *mapTypes = @[@"عادي", @"قمر صناعي", @"مختلط"];
    _mapTypeControl = [[UISegmentedControl alloc] initWithItems:mapTypes];
    _mapTypeControl.frame = CGRectMake(12, y, W - 24, 36);
    _mapTypeControl.selectedSegmentIndex = store.mapType;
    _mapTypeControl.tintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0];
    [_mapTypeControl addTarget:self action:@selector(mapTypeChanged:) forControlEvents:UIControlEventValueChanged];
    [_mainPanel addSubview:_mapTypeControl];

    y += 46;

    // زر تحديد موقعي
    _myLocationBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _myLocationBtn.frame = CGRectMake(12, y, W - 24, 40);
    _myLocationBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.9 alpha:1.0];
    _myLocationBtn.layer.cornerRadius = 10;
    [_myLocationBtn setTitle:@"📍  تحديد موقعي الحالي" forState:UIControlStateNormal];
    [_myLocationBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _myLocationBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [_myLocationBtn addTarget:self action:@selector(setMyCurrentLocation) forControlEvents:UIControlEventTouchUpInside];
    [_mainPanel addSubview:_myLocationBtn];

    y += 50;

    // قسم الارتجاج
    UIView *jitterSection = [self makeSectionWithTitle:@"⚡ الارتجاج (Jitter)" y:y width:W];
    [_mainPanel addSubview:jitterSection];

    _jitterSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(W - 60, 8, 51, 31)];
    _jitterSwitch.on = store.isJitterActive;
    _jitterSwitch.onTintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0];
    [_jitterSwitch addTarget:self action:@selector(jitterToggled:) forControlEvents:UIControlEventValueChanged];
    [jitterSection addSubview:_jitterSwitch];

    y += 54;

    // قسم محاكاة الكاميرا
    _cameraSection = [self makeSectionWithTitle:@"📷 محاكاة الكاميرا" y:y width:W];
    [_mainPanel addSubview:_cameraSection];

    _cameraSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(W - 60, 8, 51, 31)];
    _cameraSwitch.on = store.cameraSimEnabled;
    _cameraSwitch.onTintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0];
    [_cameraSwitch addTarget:self action:@selector(cameraToggled:) forControlEvents:UIControlEventValueChanged];
    [_cameraSection addSubview:_cameraSwitch];

    _cameraBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _cameraBtn.frame = CGRectMake(12, 44, W - 48, 36);
    _cameraBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0];
    _cameraBtn.layer.cornerRadius = 8;
    [_cameraBtn setTitle:@"▶  اختر صورة من الاستوديو" forState:UIControlStateNormal];
    [_cameraBtn setTitleColor:[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
    _cameraBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    _cameraBtn.hidden = !store.cameraSimEnabled;
    [_cameraBtn addTarget:self action:@selector(pickCameraImage) forControlEvents:UIControlEventTouchUpInside];
    [_cameraSection addSubview:_cameraBtn];

    y += store.cameraSimEnabled ? 90 : 54;

    // قسم إعدادات المعرف
    _identifierSection = [self makeSectionWithTitle:@"🔑 إعدادات المعرف" y:y width:W];
    [_mainPanel addSubview:_identifierSection];

    _identifierField = [[UITextField alloc] initWithFrame:CGRectMake(12, 44, W - 48, 36)];
    _identifierField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    _identifierField.layer.cornerRadius = 8;
    _identifierField.textColor = [UIColor whiteColor];
    _identifierField.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    _identifierField.text = store.activationCode;
    _identifierField.textAlignment = NSTextAlignmentCenter;
    UIView *pad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 0)];
    _identifierField.leftView = pad;
    _identifierField.leftViewMode = UITextFieldViewModeAlways;
    _identifierField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"أدخل كود التفعيل..." attributes:@{NSForegroundColorAttributeName:[UIColor colorWithWhite:0.4 alpha:1]}];
    [_identifierSection addSubview:_identifierField];

    UIButton *activateIdBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    activateIdBtn.frame = CGRectMake(12, 86, W - 48, 36);
    activateIdBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.9 alpha:1.0];
    activateIdBtn.layer.cornerRadius = 8;
    [activateIdBtn setTitle:@"تفعيل الكود" forState:UIControlStateNormal];
    [activateIdBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    activateIdBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [activateIdBtn addTarget:self action:@selector(activateCode) forControlEvents:UIControlEventTouchUpInside];
    [_identifierSection addSubview:activateIdBtn];

    y += 132;

    // قسم الإخفاء
    _hideSection = [self makeSectionWithTitle:@"👁 إعدادات الإخفاء" y:y width:W];
    [_mainPanel addSubview:_hideSection];

    UILabel *hideLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 44, 200, 28)];
    hideLabel.text = @"عدد الضغطات للإظهار:";
    hideLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    hideLabel.font = [UIFont systemFontOfSize:13];
    [_hideSection addSubview:hideLabel];

    _hideCountField = [[UITextField alloc] initWithFrame:CGRectMake(W - 80, 44, 56, 28)];
    _hideCountField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    _hideCountField.layer.cornerRadius = 6;
    _hideCountField.textColor = [UIColor whiteColor];
    _hideCountField.font = [UIFont boldSystemFontOfSize:16];
    _hideCountField.textAlignment = NSTextAlignmentCenter;
    _hideCountField.keyboardType = UIKeyboardTypeNumberPad;
    _hideCountField.text = [NSString stringWithFormat:@"%ld", (long)store.hideClickCount];
    UIView *pad2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 6, 0)];
    _hideCountField.leftView = pad2;
    _hideCountField.leftViewMode = UITextFieldViewModeAlways;
    [_hideSection addSubview:_hideCountField];

    UIButton *saveHideBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    saveHideBtn.frame = CGRectMake(12, 80, W - 48, 32);
    saveHideBtn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    saveHideBtn.layer.cornerRadius = 8;
    [saveHideBtn setTitle:@"حفظ إعدادات الإخفاء" forState:UIControlStateNormal];
    [saveHideBtn setTitleColor:[UIColor colorWithWhite:0.8 alpha:1.0] forState:UIControlStateNormal];
    saveHideBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [saveHideBtn addTarget:self action:@selector(saveHideSettings) forControlEvents:UIControlEventTouchUpInside];
    [_hideSection addSubview:saveHideBtn];

    y += 122;

    // المفضلة
    UILabel *favLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, y, 200, 28)];
    favLabel.text = @"⭐ المواقع المفضلة";
    favLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    favLabel.font = [UIFont boldSystemFontOfSize:15];
    [_mainPanel addSubview:favLabel];

    UIButton *addFavBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    addFavBtn.frame = CGRectMake(W - 100, y, 88, 28);
    [addFavBtn setTitle:@"+ حفظ الحالي" forState:UIControlStateNormal];
    [addFavBtn setTitleColor:[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
    addFavBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [addFavBtn addTarget:self action:@selector(addCurrentToFavorites) forControlEvents:UIControlEventTouchUpInside];
    [_mainPanel addSubview:addFavBtn];

    y += 34;

    _favoritesTable = [[UITableView alloc] initWithFrame:CGRectMake(12, y, W - 24, 120) style:UITableViewStylePlain];
    _favoritesTable.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    _favoritesTable.layer.cornerRadius = 10;
    _favoritesTable.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    _favoritesTable.dataSource = (id<UITableViewDataSource>)self;
    _favoritesTable.delegate = (id<UITableViewDelegate>)self;
    [_mainPanel addSubview:_favoritesTable];

    y += 130;

    // زر تفعيل تزييف الموقع الرئيسي
    _activateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _activateBtn.frame = CGRectMake(12, y, W - 24, 54);
    _activateBtn.layer.cornerRadius = 14;
    _activateBtn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self refreshActivationState];
    [_activateBtn addTarget:self action:@selector(toggleActivation) forControlEvents:UIControlEventTouchUpInside];
    [_mainPanel addSubview:_activateBtn];

    // حالة التفعيل
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, y + 60, W - 24, 24)];
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.font = [UIFont systemFontOfSize:12];
    _statusLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    [self updateStatusLabel];
    [_mainPanel addSubview:_statusLabel];

    // إضافة ScrollView
    UIScrollView *sv = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, W, H)];
    sv.contentSize = CGSizeMake(W, y + 100);
    sv.showsVerticalScrollIndicator = NO;
    [sv addSubview:_mainPanel];
    [self addSubview:sv];
}

- (UIView *)makeSectionWithTitle:(NSString *)title y:(CGFloat)y width:(CGFloat)W {
    UIView *section = [[UIView alloc] initWithFrame:CGRectMake(12, y, W - 24, 48)];
    section.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    section.layer.cornerRadius = 10;

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, W - 80, 28)];
    lbl.text = title;
    lbl.textColor = [UIColor colorWithWhite:0.85 alpha:1.0];
    lbl.font = [UIFont boldSystemFontOfSize:14];
    [section addSubview:lbl];

    return section;
}

- (void)refreshActivationState {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    if (store.isActive) {
        _activateBtn.backgroundColor = [UIColor colorWithRed:0.1 green:0.7 blue:0.2 alpha:1.0];
        [_activateBtn setTitle:@"🟢  تزييف الموقع نشط — إيقاف" forState:UIControlStateNormal];
        [_activateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    } else {
        _activateBtn.backgroundColor = [UIColor colorWithWhite:0.25 alpha:1.0];
        [_activateBtn setTitle:@"⚫  تفعيل تزييف الموقع" forState:UIControlStateNormal];
        [_activateBtn setTitleColor:[UIColor colorWithWhite:0.9 alpha:1.0] forState:UIControlStateNormal];
    }
}

- (void)updateCoordsLabel {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    _coordsLabel.text = [NSString stringWithFormat:@"%.6f , %.6f", store.fakeCoords.latitude, store.fakeCoords.longitude];
}

- (void)updateStatusLabel {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    if (store.isActivated && store.expiresAt.length > 0) {
        _statusLabel.text = [NSString stringWithFormat:@"مفعّل ✅  |  ينتهي: %@", store.expiresAt];
        _statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0];
    } else {
        _statusLabel.text = @"غير مفعّل — أدخل كود التفعيل";
        _statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
    }
}

- (void)toggleActivation {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    if (!store.isActivated) {
        [self showActivationAlert];
        return;
    }
    store.isActive = !store.isActive;
    [store save];
    [self refreshActivationState];
    [self updateCoordsLabel];
}

- (void)closePanel {
    [self removeFromSuperview];
}

- (void)setMyCurrentLocation {
    // طلب الموقع الحقيقي مرة واحدة
    CLLocationManager *lm = [[CLLocationManager alloc] init];
    CLLocation *loc = lm.location;
    if (loc) {
        WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
        store.fakeCoords = loc.coordinate;
        store.hasStoredLocation = YES;
        [store save];
        [self updateCoordsLabel];
        [self showToast:@"تم تحديد موقعك الحالي ✅"];
    } else {
        [self showToast:@"تعذر الحصول على الموقع الحالي"];
    }
}

- (void)mapTypeChanged:(UISegmentedControl *)sc {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    store.mapType = sc.selectedSegmentIndex;
    [store save];
}

- (void)jitterToggled:(UISwitch *)sw {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    store.isJitterActive = sw.on;
    [store save];
}

- (void)cameraToggled:(UISwitch *)sw {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    store.cameraSimEnabled = sw.on;
    [store save];
    _cameraBtn.hidden = !sw.on;
}

- (void)pickCameraImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    if (img) {
        [WolfoxSpoofStore shared].simulatedCameraImage = img;
        [[WolfoxSpoofStore shared] save];
        [self showToast:@"تم اختيار الصورة ✅ ستظهر كصورة كاميرا"];
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)activateCode {
    NSString *code = [_identifierField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (code.length == 0) {
        [self showToast:@"أدخل كود التفعيل أولاً"];
        return;
    }
    [self showToast:@"جاري التحقق من الكود..."];
    [[GPSApiLocal shared] activateCode:code completion:^(BOOL success, NSString *message, NSString *expiresAt) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
                store.activationCode = code;
                store.isActivated = YES;
                store.expiresAt = expiresAt ?: @"";
                [store save];
                [self updateStatusLabel];
                [self showToast:[NSString stringWithFormat:@"تم التفعيل ✅\nينتهي: %@", expiresAt ?: @""]];
            } else {
                [self showToast:[NSString stringWithFormat:@"فشل التفعيل ❌\n%@", message ?: @""]];
            }
        });
    }];
}

- (void)showActivationAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🐺 Wolf Gps" message:@"الأداة غير مفعّلة. يرجى إدخال كود التفعيل في قسم إعدادات المعرف." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:alert animated:YES completion:nil];
}

- (void)showSubscriptionInfo {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    NSString *msg;
    if (store.isActivated) {
        msg = [NSString stringWithFormat:@"الكود: %@\nحالة الاشتراك: نشط ✅\nتاريخ الانتهاء: %@\nمعرف الجهاز: %@", store.activationCode, store.expiresAt ?: @"غير محدد", store.deviceUUID];
    } else {
        msg = @"الاشتراك: غير مفعّل ❌\nيرجى إدخال كود التفعيل في قسم إعدادات المعرف.";
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"معلومات الاشتراك" message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleDefault handler:nil]];
    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:alert animated:YES completion:nil];
}

- (void)saveHideSettings {
    NSInteger count = [_hideCountField.text integerValue];
    if (count < 1) count = 1;
    if (count > 20) count = 20;
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    store.hideClickCount = count;
    [store save];
    [self showToast:[NSString stringWithFormat:@"تم الحفظ ✅\nاضغط %ld مرة لإظهار الأيقونة", (long)count]];
}

- (void)addCurrentToFavorites {
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حفظ الموقع في المفضلة" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf) {
        tf.placeholder = @"اسم الموقع...";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"حفظ" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *name = alert.textFields.firstObject.text;
        if (name.length == 0) name = [NSString stringWithFormat:@"موقع %lu", (unsigned long)store.favorites.count + 1];
        NSDictionary *fav = @{
            @"name": name,
            @"lat": @(store.fakeCoords.latitude),
            @"lon": @(store.fakeCoords.longitude)
        };
        [store.favorites addObject:fav];
        [store save];
        [self loadFavorites];
        [_favoritesTable reloadData];
        [self showToast:@"تم حفظ الموقع في المفضلة ⭐"];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *vc = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:alert animated:YES completion:nil];
}

- (void)loadFavorites {
    _favData = [[WolfoxSpoofStore shared].favorites mutableCopy];
}

// UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    return _favData.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"FavCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"FavCell"];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.5 alpha:1.0];
    }
    NSDictionary *fav = _favData[ip.row];
    cell.textLabel.text = [NSString stringWithFormat:@"⭐ %@", fav[@"name"]];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%.5f, %.5f", [fav[@"lat"] doubleValue], [fav[@"lon"] doubleValue]];
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    NSDictionary *fav = _favData[ip.row];
    WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
    store.fakeCoords = CLLocationCoordinate2DMake([fav[@"lat"] doubleValue], [fav[@"lon"] doubleValue]);
    store.hasStoredLocation = YES;
    [store save];
    [self updateCoordsLabel];
    [self showToast:[NSString stringWithFormat:@"تم تحميل: %@", fav[@"name"]]];
    [tv deselectRowAtIndexPath:ip animated:YES];
}

- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip { return YES; }

- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)es forRowAtIndexPath:(NSIndexPath *)ip {
    if (es == UITableViewCellEditingStyleDelete) {
        [WolfoxSpoofStore shared].favorites = _favData;
        [_favData removeObjectAtIndex:ip.row];
        [WolfoxSpoofStore shared].favorites = _favData;
        [[WolfoxSpoofStore shared] save];
        [tv deleteRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationFade];
    }
}

// UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    if (tf == _searchField) {
        [self searchLocation:tf.text];
        [tf resignFirstResponder];
    }
    return YES;
}

- (void)searchLocation:(NSString *)query {
    if (query.length == 0) return;
    CLGeocoder *gc = [[CLGeocoder alloc] init];
    [gc geocodeAddressString:query completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (placemarks.count > 0) {
                CLLocation *loc = placemarks.firstObject.location;
                WolfoxSpoofStore *store = [WolfoxSpoofStore shared];
                store.fakeCoords = loc.coordinate;
                store.hasStoredLocation = YES;
                [store save];
                [self updateCoordsLabel];
                [self showToast:[NSString stringWithFormat:@"تم تحديد: %@", placemarks.firstObject.name ?: query]];
            } else {
                [self showToast:@"لم يتم العثور على الموقع"];
            }
        });
    }];
}

- (void)showToast:(NSString *)msg {
    UILabel *toast = [[UILabel alloc] init];
    toast.text = msg;
    toast.numberOfLines = 0;
    toast.font = [UIFont systemFontOfSize:13];
    toast.textColor = [UIColor whiteColor];
    toast.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    toast.textAlignment = NSTextAlignmentCenter;
    toast.layer.cornerRadius = 10;
    toast.layer.masksToBounds = YES;
    CGFloat W = self.bounds.size.width;
    toast.frame = CGRectMake(W/2 - 140, self.bounds.size.height - 120, 280, 50);
    [self addSubview:toast];
    [UIView animateWithDuration:0.3 delay:2.0 options:0 animations:^{ toast.alpha = 0; } completion:^(BOOL f){ [toast removeFromSuperview]; }];
}

@end
