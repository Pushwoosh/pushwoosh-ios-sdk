//
//  PWCoreRequest.m
//  PushwooshCore
//
//  Created by André Kis on 12.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PWCoreRequest.h"
#import "NSDictionary+PWDictUtils.h"
#import "PWSettings.h"
#import "PWCoreUtils.h"
#import "PushwooshCore.h"

@implementation PWCoreRequest

- (NSString *)uid {
    return [self methodName];
}

- (NSString *)methodName {
    return @"";
}

- (NSString *)requestIdentifier {
    return [NSString stringWithFormat:@"%ld", self.hash];
}

//Please note that all values will be processed as strings
- (NSDictionary *)requestDictionary {
    return nil;
}

- (NSMutableDictionary *)baseDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary new];

    dict[@"userId"] = [PWSettings settings].userId;
    dict[@"application"] = [PWSettings settings].appCode;
    
    if (_usePreviousHWID && [PWCoreUtils isValidHwid:[PWSettings settings].previosHWID]) {
        dict[@"hwid"] = [PWSettings settings].previosHWID;
    } else {
        dict[@"hwid"] = [PWSettings settings].hwid;
    }
    
    dict[@"v"] = PUSHWOOSH_VERSION;
    dict[@"device_type"] = @(DEVICE_TYPE);

    return dict;
}

- (void)parseResponse:(NSDictionary *)response {
}

@end
