#import <Foundation/Foundation.h>

// Dummy API Header to fix build error
extern void GPSLicenseStart(void);
extern BOOL GPSLicenseIsAuthorized(void);
extern void GPSLicensePresentActivation(void);
extern NSString* GPSLicenseExpiresAt(void);

#define GPSLicenseAuthorizedNotification @"GPSLicenseAuthorizedNotification"
#define GPSLicenseRevokedNotification @"GPSLicenseRevokedNotification"
