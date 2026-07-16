#pragma once
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>

@interface WolfoxSpoofOverlay : UIViewController <UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
+ (instancetype)shared;
- (void)refreshActivationState;
- (void)showActivationAlert;
@end
