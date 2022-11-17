//
//  PWAppOpenRequest.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWAppOpenRequest.h"
#import "PWUtils.h"
#import "PushNotificationManager.h"
#import "PWPreferences.h"
#import "PWConfig.h"

#if !__has_feature(objc_arc)
#error "ARC is required to compile Pushwoosh SDK"
#endif

@interface PWAppOpenRequest () 

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
    
    NSDictionary *permissionsStatusDict = [PushNotificationManager getRemoteNotificationStatus];
    
    BOOL soundsEnabled = [permissionsStatusDict[@"pushSound"] boolValue];
    BOOL badgesEnabled = [permissionsStatusDict[@"pushBadge"] boolValue];
    BOOL alertEnabled = [permissionsStatusDict[@"pushAlert"] boolValue];
    
    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"15.0"]) {
        BOOL timeSensitive = [permissionsStatusDict[@"time_sensitive_notifications"] boolValue];
        BOOL scheduleSettings = [permissionsStatusDict[@"scheduled_summary"] boolValue];
        
        dict[@"time_sensitive_notifications"] = @(timeSensitive);
        dict[@"scheduled_summary"] = @(scheduleSettings);
    }

    
    NSInteger statusesMask = 0;
    
    if (badgesEnabled) {
        statusesMask |= 1;
    }
    
    if (soundsEnabled) {
        statusesMask |= 1 << 1;
    }
    
    if (alertEnabled) {
        statusesMask |= 1 << 2;
    }
    
    dict[@"notificationTypes"] = @(statusesMask);

	return dict;
}

- (void)parseResponse:(NSDictionary *)response {
    _businessCasesDict = response[@"required_inapps"];
}

@end
