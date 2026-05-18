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

    NSString *accepted = [[PWPreferences preferences] updateBaseUrl:baseUrl];
    if (accepted == nil) {
        return NO;
    }

    [PushwooshLog pushwooshLog:PW_LL_INFO
                     className:self
                       message:[NSString stringWithFormat:@"Base URL set to: %@", accepted]];

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
