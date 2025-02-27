//
//  PushUtils.h
//  PushNotificationManager
//
//  Created by User on 23/07/15.
//
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSErrorDomain const PWErrorDomain;

NS_ERROR_ENUM(PWErrorDomain)
{
    PWErrorUnknown = -1,
    PWErrorCommunicationDisabled = -2,
    PWErrorDeviceDataHasBeenRemoved = -3,
    PWErrorGDPRNotAvailable = -4
};

#define HEAVY_OPERATION() heavy_operation_impl(__FUNCTION__)
void heavy_operation_impl(const char *function);

@interface PWUtilsCommon : NSObject

+ (BOOL)getAPSProductionStatus:(BOOL)canShowAlert;

+ (NSString *)deviceName;

+ (NSString *)systemVersion;

+ (BOOL)isSystemVersionGreaterOrEqualTo:(NSString *)systemVersion;

+ (NSString *)machineName;

+ (NSString *)appVersion;

+ (NSString *)bundleId;

+ (NSString *)stringWithVisibleFirstAndLastFourCharacters:(NSString *)inputString;

+ (NSString *)preferredLanguage;

+ (NSString *)timezone;

+ (NSString *)uniqueGlobalDeviceIdentifier;

+ (NSError *)pushwooshError:(NSString *)description;

+ (NSError *)pushwooshErrorWithCode:(NSInteger)errorCode description:(NSString *)description;

+ (void)openUrl:(NSURL *)url;

+ (void)swizzle:(Class) class fromSelector:(SEL)fromChange toSelector:(SEL)toChange implementation:(IMP)impl typeEncoding:(const char *)typesEncoding;

+ (void)showAlertWithTitle:(NSString *)title message:(NSString *)message;

+ (BOOL)isValidHwid:(NSString*)hwid;

+ (BOOL)isValidUserId:(NSString*)userId;

+ (NSInteger)getStatusesMask;

@end
