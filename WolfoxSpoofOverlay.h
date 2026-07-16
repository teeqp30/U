#pragma once
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface WolfoxSpoofOverlay : UIView <UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (nonatomic, strong) UITextField *searchField;
@property (nonatomic, strong) UIButton *activateBtn;
@property (nonatomic, strong) UIButton *closeBtn;
@property (nonatomic, strong) UIButton *myLocationBtn;
@property (nonatomic, strong) UIButton *infoBtn;
@property (nonatomic, strong) UIButton *cameraBtn;
@property (nonatomic, strong) UIButton *settingsBtn;
@property (nonatomic, strong) UISegmentedControl *mapTypeControl;
@property (nonatomic, strong) UISwitch *jitterSwitch;
@property (nonatomic, strong) UISwitch *cameraSwitch;
@property (nonatomic, strong) UITableView *favoritesTable;
@property (nonatomic, strong) UITextField *identifierField;
@property (nonatomic, strong) UITextField *hideCountField;
@property (nonatomic, strong) UIView *mapContainer;
@property (nonatomic, strong) UIView *identifierSection;
@property (nonatomic, strong) UIView *cameraSection;
@property (nonatomic, strong) UIView *hideSection;

- (instancetype)initWithFrame:(CGRect)frame;
- (void)refreshActivationState;
- (void)showActivationAlert;

@end
