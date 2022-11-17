//
//  PWRegisterEmail.m
//  Pushwoosh
//
//  Created by Kiselev Andrey on 02.10.2020.
//  Copyright © 2020 Pushwoosh. All rights reserved.
//

#import "PWRegisterEmail.h"
#import "PWPreferences.h"

@interface PWRegisterEmail () 

@end

@implementation PWRegisterEmail

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = self.baseDictionary;
    NSUInteger tzOffset = [[NSTimeZone localTimeZone] secondsFromGMT];
    
    dict[@"email"] = self.email;
    dict[@"language"] = [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode];
    dict[@"tz_offset"] = [NSNumber numberWithInteger:tzOffset];
    
    if (dict[@"hwid"])
        [dict removeObjectForKey:@"hwid"];
    
    if (dict[@"device_type"])
        [dict removeObjectForKey:@"device_type"];
    
    
    return dict;
}

- (NSString *)methodName {
    return @"registerEmail";
}

@end
