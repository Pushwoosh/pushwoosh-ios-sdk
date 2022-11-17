//
//  PWTriggerInAppActionRequest.m
//  Pushwoosh
//
//  Created by Fectum on 05/02/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import "PWTriggerInAppActionRequest.h"

@interface PWTriggerInAppActionRequest () 

@end

@implementation PWTriggerInAppActionRequest

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = self.baseDictionary;
    
    dict[@"action"] = @"show";
    dict[@"code"] = _inAppCode;
    
    NSInteger timezone = [[NSTimeZone localTimeZone] secondsFromGMT];
    NSInteger timestampUTC = [[NSDate date] timeIntervalSince1970];
    NSInteger timestampCurrent = timestampUTC + timezone;
    
    
    dict[@"timestampUTC"] = @(timestampUTC);
    dict[@"timestampCurrent"] = @(timestampCurrent);
    
    return dict;
}

- (NSString *)methodName {
    return @"triggerInAppAction";
}

@end
