//
//  NSBundle+PWNSBundleMock.m
//  PushwooshTests
//
//  Created by Fectum on 20/09/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import "PWBundleMock.h"

@implementation PWBundleMock

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if ([key isEqualToString:@"Pushwoosh_SHOULD_SEND_PUSH_STATS_IF_ALERT_DISABLED"]) {
        return @(_sendPushStatIfAlertsDisabled);
    } else if ([key isEqualToString:@"Pushwoosh_PURCHASE_TRACKING_ENABLED"]) {
        return @(_sendPurchaseTrackingEnabled);
    } else if ([key isEqualToString:@"Pushwoosh_IDLE_TIMEOUT_SECONDS"]) {
        return _idleTimeoutSeconds;
    } else if ([key isEqualToString:@"Pushwoosh_APPLICATION_EXIT_TIMEOUT_SECONDS"]) {
        return _applicationExitTimeoutSeconds;
    } else if ([key isEqualToString:@"Pushwoosh_ALLOW_COLLECTING_EVENTS"] && _allowCollectingEventsSet) {
        return @(_allowCollectingEvents);
    } else if ([key isEqualToString:@"Pushwoosh_APPID"]) {
        return _appIdRaw ?: _appId;
    } else if ([key isEqualToString:@"PW_API_TOKEN"]) {
        return _apiToken;
    } else if ([key isEqualToString:@"Pushwoosh_API_TOKEN"]) {
        return _pushwooshApiToken;
    } else if ([key isEqualToString:@"Pushwoosh_APPID_Dev"]) {
        return _appIdDev;
    } else if ([key isEqualToString:@"Pushwoosh_APPNAME"]) {
        return _appName;
    } else if ([key isEqualToString:@"PW_APP_GROUPS_NAME"]) {
        return _appGroupsName;
    } else if ([key isEqualToString:@"Pushwoosh_BASEURL"]) {
        return _requestUrl;
    } else if ([key isEqualToString:@"Pushwoosh_GRPC_HOST"]) {
        return _grpcHost;
    } else if ([key isEqualToString:@"Pushwoosh_LOG_LEVEL"]) {
        return _logLevel;
    } else if ([key isEqualToString:@"Pushwoosh_RICH_MEDIA_STYLE"]) {
        return _richMediaStyle;
    } else {
        return [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    }
}



@end

