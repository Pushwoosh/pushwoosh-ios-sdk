//
//  PWSetEmailTagsRequest.m
//  Pushwoosh
//
//  Created by Kiselev Andrey on 02.10.2020.
//  Copyright © 2020 Pushwoosh. All rights reserved.
//

#import "PWSetEmailTagsRequest.h"
#import "NSDate+PWDateUtils.h"

@interface PWSetEmailTagsRequest () 

@end

@implementation PWSetEmailTagsRequest

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [self baseDictionary];
    NSMutableDictionary *mutableTags = [_tags mutableCopy];

    for (NSString *key in [mutableTags allKeys]) {
        NSString *valueString = @"";
        NSObject *value = mutableTags[key];

        if ([value isKindOfClass:[NSString class]]) {
            valueString = (NSString *)value;
        } else if ([value isKindOfClass:[NSDate class]]) {
            NSDate *dateTag = (NSDate *)value;
            mutableTags[key] = dateTag.pw_formattedDate;
        }
    }

    dict[@"tags"] = mutableTags;
    dict[@"email"] = self.email;
    
    if (dict[@"hwid"])
        [dict removeObjectForKey:@"hwid"];
    
    if (dict[@"content-type"])
        [dict removeObjectForKey:@"device_type"];
    
    return dict;
}

- (NSString *)methodName {
    return @"setEmailTags";
}

@end
