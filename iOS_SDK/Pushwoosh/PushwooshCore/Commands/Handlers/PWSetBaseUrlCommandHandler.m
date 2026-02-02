//
//  PWSetBaseUrlCommandHandler.m
//  PushwooshCore
//
//  Created by André Kis on 26.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWSetBaseUrlCommandHandler.h"
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWPreferences.h>

static NSString *const kPWCommandSetBaseUrl = @"set_base_url";
static NSString *const kPWValueKey = @"value";

@implementation PWSetBaseUrlCommandHandler

#pragma mark - PWSystemCommandHandler

- (NSString *)commandName {
    return kPWCommandSetBaseUrl;
}

- (BOOL)handleCommand:(NSDictionary *)userInfo {
    NSString *baseUrl = [self extractValue:userInfo];

    if (!baseUrl) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:@"set_base_url command received but 'value' is missing"];
        return NO;
    }

    if (![self isValidUrl:baseUrl]) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:[NSString stringWithFormat:@"Invalid URL: %@", baseUrl]];
        return NO;
    }

    // Persist to preferences (NSUserDefaults) - all network requests read from here
    [PWPreferences preferences].baseUrl = baseUrl;

    [PushwooshLog pushwooshLog:PW_LL_INFO
                     className:self
                       message:[NSString stringWithFormat:@"Base URL set to: %@", baseUrl]];

    return YES;
}

- (BOOL)isValidUrl:(NSString *)url {
    if (![url hasPrefix:@"https://"] && ![url hasPrefix:@"http://"]) {
        return NO;
    }
    NSURL *nsUrl = [NSURL URLWithString:url];
    return nsUrl != nil;
}

#pragma mark - Private Methods

- (NSString *)extractValue:(NSDictionary *)userInfo {
    id value = userInfo[kPWValueKey];

    if ([value isKindOfClass:[NSString class]]) {
        return value;
    }

    return nil;
}

@end
