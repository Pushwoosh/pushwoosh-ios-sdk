//
//  PWAppOpenRequest.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWAppOpenRequest.h"
#import "PWUtils.h"
#import "PWPreferences.h"
#import "PWConfig.h"
#import <PushwooshCore/PWManagerBridge.h>

@interface PWAppOpenRequest ()

@property (nonatomic, copy, readwrite) NSString *pushPermissionStatus;

@end

@implementation PWAppOpenRequest

- (instancetype)init {
    if (self = [super init]) {
        self.cacheable = NO;
    }
    return self;
}

- (NSString *)methodName {
	return @"applicationOpen";
}

+ (NSString *)pushPermissionStatusFromNotificationStatus:(NSDictionary *)notificationStatus {
    NSString *status = notificationStatus[@"push_permission_status"];
    return [status isKindOfClass:[NSString class]] && status.length > 0 ? status : nil;
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [self baseDictionary];

	NSString *package = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
	if (package) {
		dict[@"package"] = package;
	}

    NSString *timeZone = [PWUtils timezone];
    if (timeZone) {
        dict[@"timezone"] = [PWUtils timezone];
    }

	NSString *appVersion = [PWUtils appVersion];
	if (appVersion) {
		dict[@"app_version"] = appVersion;
	}

    if ([PWConfig config].allowCollectingDeviceOsVersion == YES) {
        NSString *systemVersion = [PWUtils systemVersion];
        dict[@"os_version"] = systemVersion;
    }

    if ([PWConfig config].allowCollectingDeviceModel == YES) {
        NSString *machineName = [PWUtils machineName];
        dict[@"device_model"] = machineName;
    }

    if ([PWConfig config].allowCollectingDeviceLocale == YES) {
        dict[@"language"] = [PWPreferences preferences].language;
    }

    NSDictionary *permissionsStatusDict = self.notificationStatus ?: [PWManagerBridge getRemoteNotificationStatus];

    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"15.0"]) {
        BOOL timeSensitive = [permissionsStatusDict[@"time_sensitive_notifications"] boolValue];
        BOOL scheduleSettings = [permissionsStatusDict[@"scheduled_summary"] boolValue];

        dict[@"time_sensitive_notifications"] = @(timeSensitive);
        dict[@"scheduled_summary"] = @(scheduleSettings);
    }

    self.pushPermissionStatus = [PWAppOpenRequest pushPermissionStatusFromNotificationStatus:permissionsStatusDict];
    if (self.pushPermissionStatus) {
        dict[@"push_permission_status"] = self.pushPermissionStatus;
    }

    dict[@"notificationTypes"] = @([PWUtils statusesMaskFromNotificationStatus:permissionsStatusDict]);

	return dict;
}

@end
