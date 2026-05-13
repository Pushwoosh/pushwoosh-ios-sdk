//
//  PWSetAdvertisingIdRequest.m
//  PushwooshCore
//
//  Created by André Kis on 25.03.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWSetAdvertisingIdRequest.h"
#import "PWConfig.h"
#import "PWPreferences.h"

static NSString *const kDefaultTrackingUrl = @"https://tracking.svc-nue.pushwoosh.com/api/v2/device-api/";

@implementation PWSetAdvertisingIdRequest

- (NSString *)methodName {
    return @"setMADID";
}

- (BOOL)shouldWrapRequest {
    return NO;
}

- (NSString *)baseUrl {
    NSString *configUrl = [PWConfig config].trackingUrl;
    if (configUrl.length > 0) {
        if (![configUrl hasSuffix:@"/"]) {
            configUrl = [configUrl stringByAppendingString:@"/"];
        }
        return configUrl;
    }

    return kDefaultTrackingUrl;
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];

    dict[@"application"] = [PWPreferences preferences].appCode;
    dict[@"hwid"] = [PWPreferences preferences].hwid;
    dict[@"madid"] = self.advertisingId ?: [NSNull null];

    return dict;
}

@end
