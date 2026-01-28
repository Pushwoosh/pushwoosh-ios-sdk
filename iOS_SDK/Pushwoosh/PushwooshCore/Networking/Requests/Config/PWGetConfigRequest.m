//
//  PWGetConfigRequest.m
//  Pushwoosh
//
//  Created by Anton Kaizer on 27/09/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWGetConfigRequest.h"
#import "NSDictionary+PWDictUtils.h"

@interface PWGetConfigRequest () 

@end

@implementation PWGetConfigRequest

- (NSString *)methodName {
    return @"getConfig";
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *requestDict = [self baseDictionary];
    requestDict[@"features"] = @[
        @"events"
    ];
    return [requestDict copy];
}

- (void)parseResponse:(NSDictionary *)response {
    NSDictionary *featuresDictionary = response[@"features"];
    
    if (featuresDictionary && [featuresDictionary isKindOfClass:[NSDictionary class]]) {
        if ([[featuresDictionary allKeys] containsObject:@"logger"] && [[featuresDictionary pw_numberForKey:@"logger"] isKindOfClass:[NSNumber class]]) {
            if ([[featuresDictionary pw_numberForKey:@"logger"] intValue] != 0) {
                _isLoggerActive = YES;
            } else {
                _isLoggerActive = NO;
            }
        } else {
            _isLoggerActive = NO;
        }
        
        NSArray *eventsDicts = [featuresDictionary pw_arrayForKey:@"events"];
        _events = [eventsDicts copy];
    } else {
        _isLoggerActive = NO;
    }
}

@end
