//
//  PWAppOpenRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRequest.h"
#import <PushwooshCore/PWPreferences.h>

@interface PWAppOpenRequest : PWRequest

@property (nonatomic, copy, readonly, nullable) NSString *pushPermissionStatus;

/// Settings snapshot the caller already read; when nil the request reads them itself (blocking).
@property (nonatomic, copy, nullable) NSDictionary *notificationStatus;

+ (nullable NSString *)pushPermissionStatusFromNotificationStatus:(nullable NSDictionary *)notificationStatus;

@end
