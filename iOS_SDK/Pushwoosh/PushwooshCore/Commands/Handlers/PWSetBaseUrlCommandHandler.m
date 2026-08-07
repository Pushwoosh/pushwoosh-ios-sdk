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
#import <PushwooshCore/PWRequestManager.h>
#import "PWNetworkModule.h"

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

    if ([[PWNetworkModule module].requestManager isUsingReverseProxy]) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:@"set_base_url command ignored: a reverse proxy is configured, and the proxy URL outranks the base URL for every request anyway."];
        return NO;
    }

    NSString *previous = [[PWPreferences preferences] baseUrl];
    NSString *accepted = [[PWPreferences preferences] updateBaseUrl:baseUrl];
    if (accepted == nil) {
        return NO;
    }

    [PushwooshLog pushwooshLog:PW_LL_WARN
                     className:self
                       message:[NSString stringWithFormat:@"Base URL moved by a server command: %@ -> %@. The application selected with setAppCode(_:baseUrl:) is unchanged. To return to your own endpoint, call setAppCode(<code>, baseUrl:<your endpoint>) again.",
                                [NSURL URLWithString:previous ?: @""].host ?: @"(none)",
                                [NSURL URLWithString:accepted].host ?: @"(none)"]];

    return YES;
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
