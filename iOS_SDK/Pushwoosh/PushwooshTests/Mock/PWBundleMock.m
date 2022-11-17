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
    } else {
        return [[NSBundle mainBundle] objectForInfoDictionaryKey:key];
    }
}



@end

