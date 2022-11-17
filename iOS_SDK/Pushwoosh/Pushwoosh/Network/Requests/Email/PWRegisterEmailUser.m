//
//  PWRegisterEmailUser.m
//  Pushwoosh
//
//  Created by Kiselev Andrey on 02.10.2020.
//  Copyright © 2020 Pushwoosh. All rights reserved.
//

#import "PWRegisterEmailUser.h"
#import "PWPreferences.h"

@interface PWRegisterEmailUser () 

@end

@implementation PWRegisterEmailUser

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = self.baseDictionary;

    dict[@"email"] = self.email;
    dict[@"userId"] = self.userId;
    NSUInteger tzOffset = [[NSTimeZone localTimeZone] secondsFromGMT];
    dict[@"tz_offset"] = [NSNumber numberWithInteger:tzOffset];
    
    if (dict[@"hwid"])
        [dict removeObjectForKey:@"hwid"];
    
    if (dict[@"device_type"])
        [dict removeObjectForKey:@"device_type"];
    
    return dict;
}

- (NSString *)methodName {
    return @"registerEmailUser";
}


@end
