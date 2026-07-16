#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

void GPSLicenseStart(void);
BOOL GPSLicenseIsAuthorized(void);
void GPSLicensePresentActivation(void);
void GPSLicenseActivateCode(NSString *code);
NSString* GPSLicenseExpiresAt(void);
NSString* GPSLicenseDeviceUUID(void);
NSString* GPSLicenseSupportURL(void);
void WolfoxToggleMainPanel(void);

#define GPSLicenseAuthorizedNotification @"GPSLicenseAuthorizedNotification"
#define GPSLicenseRevokedNotification @"GPSLicenseRevokedNotification"

#ifdef __cplusplus
}
#endif
