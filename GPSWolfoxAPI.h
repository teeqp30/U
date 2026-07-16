#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

void GPSLicenseStart(void);
BOOL GPSLicenseIsAuthorized(void);
void GPSLicensePresentActivation(void);
NSString* GPSLicenseExpiresAt(void);

#define GPSLicenseAuthorizedNotification @"GPSLicenseAuthorizedNotification"
#define GPSLicenseRevokedNotification @"GPSLicenseRevokedNotification"

#ifdef __cplusplus
}
#endif
