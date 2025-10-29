//
//  PWStartLiveActivityRequest.m
//  Pushwoosh
//
//  Created by Andrew Kis on 25.4.24..
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import "PWStartLiveActivityRequest.h"

@implementation PWStartLiveActivityRequest

- (NSString *)methodName {
    return @"setActivityPushToStartToken";
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = self.baseDictionary;
    
    dict[@"activity_push_to_start_token"] = _token;
    
    return dict;
}

@end
