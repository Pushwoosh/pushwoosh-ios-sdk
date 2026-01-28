//
//  PWSetLogLevelCommandHandler.m
//  PushwooshCore
//
//  Created by André Kis on 26.01.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import "PWSetLogLevelCommandHandler.h"
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWPreferences.h>

static NSString *const kPWCommandSetLogLevel = @"setLogLevel";
static NSString *const kPWValueKey = @"value";

@implementation PWSetLogLevelCommandHandler

#pragma mark - PWSystemCommandHandler

- (NSString *)commandName {
    return kPWCommandSetLogLevel;
}

- (BOOL)handleCommand:(NSDictionary *)userInfo {
    NSString *logLevelString = [self extractValue:userInfo];

    if (!logLevelString) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:@"setLogLevel command received but 'value' is missing"];
        return NO;
    }

    PUSHWOOSH_LOG_LEVEL logLevel = [self logLevelFromString:logLevelString];

    // Persist to preferences (NSUserDefaults) - PushwooshLog reads from here
    [PWPreferences preferences].logLevel = (unsigned int)logLevel;

    [PushwooshLog pushwooshLog:PW_LL_INFO
                     className:self
                       message:[NSString stringWithFormat:@"Log level set to: %@ (%lu)",
                                logLevelString, (unsigned long)logLevel]];

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

- (PUSHWOOSH_LOG_LEVEL)logLevelFromString:(NSString *)string {
    NSString *uppercaseString = [string uppercaseString];

    static NSDictionary<NSString *, NSNumber *> *logLevelMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logLevelMap = @{
            @"NONE": @(PW_LL_NONE),
            @"ERROR": @(PW_LL_ERROR),
            @"WARN": @(PW_LL_WARN),
            @"WARNING": @(PW_LL_WARN),
            @"INFO": @(PW_LL_INFO),
            @"DEBUG": @(PW_LL_DEBUG),
            @"VERBOSE": @(PW_LL_VERBOSE)
        };
    });

    NSNumber *logLevelNumber = logLevelMap[uppercaseString];

    if (logLevelNumber) {
        return (PUSHWOOSH_LOG_LEVEL)[logLevelNumber unsignedIntegerValue];
    }

    [PushwooshLog pushwooshLog:PW_LL_WARN
                     className:self
                       message:[NSString stringWithFormat:@"Unknown log level: %@, defaulting to INFO", string]];

    return PW_LL_INFO;
}

@end
