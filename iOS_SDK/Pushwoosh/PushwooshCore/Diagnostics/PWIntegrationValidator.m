/*
 *  PWIntegrationValidator.m
 *  PushwooshCore
 *
 *  Created by André Kis on 10.06.26.
 *  Copyright © 2026 Pushwoosh. All rights reserved.
 */

#import "PWIntegrationValidator.h"
#import "PushwooshLog.h"
#import "PWUtils.h"
#import <PushwooshCore/PushwooshCore.h>

static NSString * const kDisableIntegrationCheckKey = @"Pushwoosh_DISABLE_INTEGRATION_CHECK";
static NSString * const kAppIdKey = @"Pushwoosh_APPID";
static NSString * const kAppIdDevKey = @"Pushwoosh_APPID_Dev";
static NSString * const kApiTokenKey = @"Pushwoosh_API_TOKEN";
static NSString * const kLegacyApiTokenKey = @"PW_API_TOKEN";
static NSString * const kAppGroupsKey = @"PW_APP_GROUPS_NAME";
static NSString * const kGRPCImplementationClassName = @"PushwooshGRPC.PushwooshGRPCImplementation";

@interface PWIntegrationFinding ()

@property (nonatomic, copy, readwrite) NSString *ruleId;
@property (nonatomic, readwrite) PWIntegrationSeverity severity;
@property (nonatomic, copy, readwrite) NSString *message;
@property (nonatomic, copy, readwrite) NSString *fixHint;

@end

@implementation PWIntegrationFinding

+ (instancetype)findingWithRule:(NSString *)ruleId
                       severity:(PWIntegrationSeverity)severity
                        message:(NSString *)message
                        fixHint:(NSString *)fixHint {
    PWIntegrationFinding *finding = [PWIntegrationFinding new];
    finding.ruleId = ruleId;
    finding.severity = severity;
    finding.message = message;
    finding.fixHint = fixHint;
    return finding;
}

@end

@implementation PWIntegrationValidator

+ (void)scheduleValidationWithAppCode:(NSString *)appCode {
    static dispatch_once_t validationOnceToken;
    dispatch_once(&validationOnceToken, ^{
        NSBundle *bundle = [NSBundle mainBundle];
        id disableFlag = [bundle objectForInfoDictionaryKey:kDisableIntegrationCheckKey];
        if (([disableFlag isKindOfClass:[NSNumber class]] || [disableFlag isKindOfClass:[NSString class]]) && [disableFlag boolValue]) {
            return;
        }
        if ([bundle objectForInfoDictionaryKey:@"NSExtension"] != nil) {
            return;
        }

        NSString *apiToken = [PushwooshConfig getApiToken];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @try {
                NSArray<PWIntegrationFinding *> *findings = [self runChecksWithBundle:bundle
                                                                      resolvedAppCode:appCode
                                                                     resolvedApiToken:apiToken];
                [self logReport:findings];
            } @catch (NSException *exception) {
                [PushwooshLog pushwooshLog:PW_LL_DEBUG
                                 className:self
                                   message:[NSString stringWithFormat:@"Integration check failed: %@", exception.reason]];
            }
        });
    });
}

#pragma mark - Rules

+ (NSArray<PWIntegrationFinding *> *)runChecksWithBundle:(NSBundle *)bundle {
    return [self runChecksWithBundle:bundle resolvedAppCode:nil resolvedApiToken:nil];
}

+ (NSArray<PWIntegrationFinding *> *)runChecksWithBundle:(NSBundle *)bundle
                                         resolvedAppCode:(NSString *)resolvedAppCode
                                        resolvedApiToken:(NSString *)resolvedApiToken {
    NSMutableArray<PWIntegrationFinding *> *findings = [NSMutableArray new];
    [findings addObjectsFromArray:[self checkAppIdInBundle:bundle resolvedAppCode:resolvedAppCode]];
    [findings addObjectsFromArray:[self checkApiTokenInBundle:bundle resolvedApiToken:resolvedApiToken]];
    [findings addObjectsFromArray:[self checkKeyTyposInBundle:bundle]];
#if TARGET_OS_IOS
    [findings addObjectsFromArray:[self checkBackgroundModesInBundle:bundle]];
    [findings addObjectsFromArray:[self checkNotificationServiceExtensionInBundle:bundle]];
#endif
    [findings addObjectsFromArray:[self checkAppGroupInBundle:bundle]];
    [findings addObjectsFromArray:[self checkGRPCModuleInBundle:bundle]];
    return findings;
}

+ (NSString *)trimmedStringForKey:(NSString *)key inBundle:(NSBundle *)bundle {
    return [self trimmedNonEmptyString:[bundle objectForInfoDictionaryKey:key]];
}

+ (NSString *)trimmedNonEmptyString:(id)value {
    if (![value isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : nil;
}

+ (NSArray<PWIntegrationFinding *> *)checkAppIdInBundle:(NSBundle *)bundle resolvedAppCode:(NSString *)resolvedAppCode {
    NSMutableArray<PWIntegrationFinding *> *findings = [NSMutableArray new];
    [findings addObject:[self appIdFindingInBundle:bundle resolvedAppCode:resolvedAppCode]];
    PWIntegrationFinding *devFinding = [self appIdDevFindingInBundle:bundle];
    if (devFinding) {
        [findings addObject:devFinding];
    }
    return findings;
}

+ (PWIntegrationFinding *)appIdFindingInBundle:(NSBundle *)bundle resolvedAppCode:(NSString *)resolvedAppCode {
    NSString *appId = [self trimmedStringForKey:kAppIdKey inBundle:bundle];
    BOOL setAtRuntime = NO;
    if (appId.length == 0) {
        appId = [self trimmedNonEmptyString:resolvedAppCode];
        setAtRuntime = appId.length > 0;
    }

    if (appId.length == 0) {
        return [PWIntegrationFinding findingWithRule:@"appid.present"
                                            severity:PWIntegrationSeverityError
                                             message:@"Pushwoosh_APPID is missing from Info.plist"
                                             fixHint:@"Add Pushwoosh_APPID (format XXXXX-XXXXX, from Pushwoosh Control Panel) to Info.plist"];
    }

    if ([appId rangeOfString:@"."].location != NSNotFound) {
        BOOL sdkResolvedWorkingCode = !setAtRuntime && [self trimmedNonEmptyString:resolvedAppCode] != nil;
        return [PWIntegrationFinding findingWithRule:@"appid.deprecated"
                                            severity:sdkResolvedWorkingCode ? PWIntegrationSeverityWarning : PWIntegrationSeverityError
                                             message:[NSString stringWithFormat:@"Application id '%@' uses the deprecated dotted format and is ignored by the SDK", appId]
                                             fixHint:@"Use the XXXXX-XXXXX app code from Pushwoosh Control Panel or contact Pushwoosh support"];
    }

    PWIntegrationFinding *formatFinding = [self formatFindingForAppId:appId key:kAppIdKey];
    if (formatFinding) {
        return formatFinding;
    }

    NSString *okMessage = setAtRuntime
        ? [NSString stringWithFormat:@"Application id: %@ (set at runtime)", appId]
        : [NSString stringWithFormat:@"Application id: %@", appId];
    return [PWIntegrationFinding findingWithRule:@"appid.present"
                                        severity:PWIntegrationSeverityOK
                                         message:okMessage
                                         fixHint:nil];
}

+ (PWIntegrationFinding *)appIdDevFindingInBundle:(NSBundle *)bundle {
    NSString *appIdDev = [self trimmedStringForKey:kAppIdDevKey inBundle:bundle];
    if (appIdDev == nil) {
        return nil;
    }
    if ([appIdDev rangeOfString:@"."].location != NSNotFound) {
        return [PWIntegrationFinding findingWithRule:@"appid.deprecated"
                                            severity:PWIntegrationSeverityWarning
                                             message:[NSString stringWithFormat:@"%@ '%@' uses the deprecated dotted format and is ignored by the SDK", kAppIdDevKey, appIdDev]
                                             fixHint:@"Use the XXXXX-XXXXX app code from Pushwoosh Control Panel or contact Pushwoosh support"];
    }
    return [self formatFindingForAppId:appIdDev key:kAppIdDevKey];
}

+ (PWIntegrationFinding *)formatFindingForAppId:(NSString *)appId key:(NSString *)key {
    NSPredicate *format = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"^[A-Za-z0-9]{5}-[A-Za-z0-9]{5}$"];
    if ([format evaluateWithObject:appId]) {
        return nil;
    }
    return [PWIntegrationFinding findingWithRule:@"appid.format"
                                        severity:PWIntegrationSeverityWarning
                                         message:[NSString stringWithFormat:@"%@ '%@' does not match the expected XXXXX-XXXXX format", key, appId]
                                         fixHint:@"Verify the app code in Pushwoosh Control Panel → Application settings"];
}

+ (NSArray<PWIntegrationFinding *> *)checkApiTokenInBundle:(NSBundle *)bundle resolvedApiToken:(NSString *)resolvedApiToken {
    NSString *token = [self trimmedStringForKey:kApiTokenKey inBundle:bundle];
    NSString *legacyToken = [self trimmedStringForKey:kLegacyApiTokenKey inBundle:bundle];
    if (token.length == 0 && legacyToken.length == 0) {
        if ([self trimmedNonEmptyString:resolvedApiToken] != nil) {
            return @[[PWIntegrationFinding findingWithRule:@"apitoken.present"
                                                  severity:PWIntegrationSeverityOK
                                                   message:@"API token: set at runtime"
                                                   fixHint:nil]];
        }
        return @[[PWIntegrationFinding findingWithRule:@"apitoken.present"
                                              severity:PWIntegrationSeverityWarning
                                               message:@"Pushwoosh_API_TOKEN is missing from Info.plist"
                                               fixHint:@"Add Pushwoosh_API_TOKEN (Device API token from Pushwoosh Control Panel → API Access)"]];
    }
    NSString *presentKey = token.length > 0 ? kApiTokenKey : kLegacyApiTokenKey;
    return @[[PWIntegrationFinding findingWithRule:@"apitoken.present"
                                          severity:PWIntegrationSeverityOK
                                           message:[NSString stringWithFormat:@"%@: present", presentKey]
                                           fixHint:nil]];
}

+ (NSArray<NSString *> *)knownConfigurationKeys {
    return @[
        @"Pushwoosh_APPID",
        @"Pushwoosh_APPID_Dev",
        @"Pushwoosh_API_TOKEN",
        @"Pushwoosh_APPNAME",
        @"Pushwoosh_AUTO",
        @"Pushwoosh_AUTO_ACCEPT_DEEP_LINK_FOR_SILENT_PUSH",
        @"Pushwoosh_ALLOW_COLLECTING_DEVICE_DATA",
        @"Pushwoosh_ALLOW_COLLECTING_DEVICE_LOCALE",
        @"Pushwoosh_ALLOW_COLLECTING_DEVICE_MODEL",
        @"Pushwoosh_ALLOW_COLLECTING_DEVICE_OS_VERSION",
        @"Pushwoosh_ALLOW_COLLECTING_EVENTS",
        @"Pushwoosh_ALLOW_REVERSE_PROXY",
        @"Pushwoosh_ALLOW_SERVER_COMMUNICATION",
        @"Pushwoosh_APPLICATION_EXIT_TIMEOUT_SECONDS",
        @"Pushwoosh_BASEURL",
        @"Pushwoosh_DEBUG",
        @"Pushwoosh_DISABLE_URL_FALLBACK",
        @"Pushwoosh_DISABLE_INTEGRATION_CHECK",
        @"Pushwoosh_GRPC_HOST",
        @"Pushwoosh_GRPC_PORT",
        @"Pushwoosh_IDLE_TIMEOUT_SECONDS",
        @"Pushwoosh_LAZY_INITIALIZATION",
        @"Pushwoosh_LOG_LEVEL",
        @"Pushwoosh_PLUGIN_NOTIFICATION_HANDLER",
        @"Pushwoosh_PREFER_GRPC",
        @"Pushwoosh_PREHANDLE_URL_NOTIFICATIONS",
        @"Pushwoosh_PURCHASE_TRACKING_ENABLED",
        @"Pushwoosh_RICH_MEDIA_STYLE",
        @"Pushwoosh_SHOULD_SEND_PUSH_STATS_IF_ALERT_DISABLED",
        @"Pushwoosh_SHOW_ALERT",
        @"Pushwoosh_TRACKING_URL",
        @"PW_API_TOKEN",
        @"PW_APP_GROUPS_NAME",
        @"PWAutoAcceptDeepLinkForSilentPush",
    ];
}

+ (NSArray<PWIntegrationFinding *> *)checkKeyTyposInBundle:(NSBundle *)bundle {
    NSDictionary *info = bundle.infoDictionary;
    if (![info isKindOfClass:[NSDictionary class]]) {
        return @[];
    }

    NSArray<NSString *> *knownKeys = [self knownConfigurationKeys];
    NSSet<NSString *> *knownKeySet = [NSSet setWithArray:knownKeys];
    NSMutableArray<PWIntegrationFinding *> *findings = [NSMutableArray new];

    for (NSString *key in info.allKeys) {
        if (![key isKindOfClass:[NSString class]] || [knownKeySet containsObject:key]) {
            continue;
        }
        NSString *lowercaseKey = key.lowercaseString;
        BOOL looksLikeOurs = [lowercaseKey hasPrefix:@"pushwoosh"] ||
                             [lowercaseKey hasPrefix:@"pw_"];
        BOOL pushwooshLike = looksLikeOurs ||
                             [lowercaseKey hasPrefix:@"pw"] ||
                             [lowercaseKey containsString:@"push"];
        if (!pushwooshLike) {
            continue;
        }

        NSString *closestKey = nil;
        NSUInteger closestDistance = NSUIntegerMax;
        for (NSString *known in knownKeys) {
            NSUInteger distance = [self levenshteinDistanceFrom:lowercaseKey to:known.lowercaseString];
            if (distance < closestDistance) {
                closestDistance = distance;
                closestKey = known;
            }
        }

        if (closestDistance <= 2) {
            [findings addObject:[PWIntegrationFinding findingWithRule:@"plist.typo"
                                                             severity:PWIntegrationSeverityWarning
                                                              message:[NSString stringWithFormat:@"Unknown Info.plist key '%@' — did you mean '%@'?", key, closestKey]
                                                              fixHint:[NSString stringWithFormat:@"Rename the key to '%@' in Info.plist", closestKey]]];
        } else if (looksLikeOurs) {
            [findings addObject:[PWIntegrationFinding findingWithRule:@"plist.unknown"
                                                             severity:PWIntegrationSeverityInfo
                                                              message:[NSString stringWithFormat:@"Info.plist key '%@' is not recognized by the Pushwoosh SDK", key]
                                                              fixHint:nil]];
        }
    }
    return findings;
}

+ (NSUInteger)levenshteinDistanceFrom:(NSString *)source to:(NSString *)target {
    NSUInteger sourceLength = source.length;
    NSUInteger targetLength = target.length;
    if (sourceLength == 0) return targetLength;
    if (targetLength == 0) return sourceLength;

    NSUInteger columns = targetLength + 1;
    NSUInteger *previousRow = calloc(columns, sizeof(NSUInteger));
    NSUInteger *currentRow = calloc(columns, sizeof(NSUInteger));

    for (NSUInteger column = 0; column < columns; column++) {
        previousRow[column] = column;
    }
    for (NSUInteger row = 1; row <= sourceLength; row++) {
        currentRow[0] = row;
        unichar sourceChar = [source characterAtIndex:row - 1];
        for (NSUInteger column = 1; column <= targetLength; column++) {
            NSUInteger substitutionCost = (sourceChar == [target characterAtIndex:column - 1]) ? 0 : 1;
            NSUInteger deletion = previousRow[column] + 1;
            NSUInteger insertion = currentRow[column - 1] + 1;
            NSUInteger substitution = previousRow[column - 1] + substitutionCost;
            currentRow[column] = MIN(MIN(deletion, insertion), substitution);
        }
        NSUInteger *swap = previousRow;
        previousRow = currentRow;
        currentRow = swap;
    }
    NSUInteger result = previousRow[targetLength];
    free(previousRow);
    free(currentRow);
    return result;
}

+ (NSArray<PWIntegrationFinding *> *)checkAppGroupInBundle:(NSBundle *)bundle {
    NSString *groupName = [self trimmedStringForKey:kAppGroupsKey inBundle:bundle];
    if (groupName.length == 0) {
        return @[];
    }
#if TARGET_OS_SIMULATOR
    /*
     The simulator does not enforce entitlements — containerURLForSecurityApplicationGroupIdentifier:
     succeeds for any group name, so a positive result there would falsely confirm a missing
     App Groups capability. The rule only runs on real devices.
     */
    return @[];
#else
    NSURL *container = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:groupName];
    if (container == nil) {
        return @[[PWIntegrationFinding findingWithRule:@"appgroup.reachable"
                                              severity:PWIntegrationSeverityError
                                               message:[NSString stringWithFormat:@"PW_APP_GROUPS_NAME is set to '%@' but the app group container is not accessible", groupName]
                                               fixHint:[NSString stringWithFormat:@"Add the App Groups capability with group '%@' to the target's Signing & Capabilities", groupName]]];
    }
    return @[[PWIntegrationFinding findingWithRule:@"appgroup.reachable"
                                          severity:PWIntegrationSeverityOK
                                           message:[NSString stringWithFormat:@"App group '%@' is accessible", groupName]
                                           fixHint:nil]];
#endif
}

+ (NSArray<PWIntegrationFinding *> *)checkGRPCModuleInBundle:(NSBundle *)bundle {
    NSNumber *preferGRPC = [bundle objectForInfoDictionaryKey:@"Pushwoosh_PREFER_GRPC"];
    if (![preferGRPC respondsToSelector:@selector(boolValue)] || ![preferGRPC boolValue]) {
        return @[];
    }
    if (NSClassFromString(kGRPCImplementationClassName) == nil) {
        return @[[PWIntegrationFinding findingWithRule:@"module.grpc"
                                              severity:PWIntegrationSeverityWarning
                                               message:@"Pushwoosh_PREFER_GRPC is enabled but the PushwooshGRPC module is not linked"
                                               fixHint:@"Add the PushwooshGRPC dependency or remove Pushwoosh_PREFER_GRPC from Info.plist"]];
    }
    return @[[PWIntegrationFinding findingWithRule:@"module.grpc"
                                          severity:PWIntegrationSeverityOK
                                           message:@"gRPC transport: linked"
                                           fixHint:nil]];
}

#if TARGET_OS_IOS

+ (NSArray<PWIntegrationFinding *> *)checkBackgroundModesInBundle:(NSBundle *)bundle {
    NSArray *backgroundModes = [bundle objectForInfoDictionaryKey:@"UIBackgroundModes"];
    BOOL hasRemoteNotification = [backgroundModes isKindOfClass:[NSArray class]] &&
                                 [backgroundModes containsObject:@"remote-notification"];
    if (!hasRemoteNotification) {
        return @[[PWIntegrationFinding findingWithRule:@"backgroundmodes.remote"
                                              severity:PWIntegrationSeverityInfo
                                               message:@"UIBackgroundModes does not include 'remote-notification' — silent pushes will not be delivered in background"
                                               fixHint:@"Enable Background Modes → Remote notifications if you use silent pushes"]];
    }
    return @[[PWIntegrationFinding findingWithRule:@"backgroundmodes.remote"
                                          severity:PWIntegrationSeverityOK
                                           message:@"Background mode 'remote-notification': enabled"
                                           fixHint:nil]];
}

+ (NSArray<PWIntegrationFinding *> *)checkNotificationServiceExtensionInBundle:(NSBundle *)bundle {
    NSBundle *appexBundle = [self notificationServiceExtensionBundleIn:bundle];
    if (!appexBundle) {
        return @[[PWIntegrationFinding findingWithRule:@"nse.present"
                                              severity:PWIntegrationSeverityInfo
                                               message:@"No Notification Service Extension found — delivery events and rich media attachments will not work"
                                               fixHint:@"Add a Notification Service Extension target with PushwooshFramework (see integration guide)"]];
    }

    NSMutableArray<PWIntegrationFinding *> *findings = [NSMutableArray new];
    NSString *appexName = appexBundle.bundleURL.lastPathComponent;

    NSString *hostAppId = [self trimmedStringForKey:kAppIdKey inBundle:bundle];
    NSString *appexAppId = [self trimmedStringForKey:kAppIdKey inBundle:appexBundle];
    if (hostAppId && appexAppId && ![hostAppId isEqualToString:appexAppId]) {
        [findings addObject:[PWIntegrationFinding findingWithRule:@"nse.appid.mismatch"
                                                         severity:PWIntegrationSeverityWarning
                                                          message:[NSString stringWithFormat:@"Pushwoosh_APPID differs between app ('%@') and %@ ('%@')", hostAppId, appexName, appexAppId]
                                                          fixHint:@"Use the same Pushwoosh_APPID in both targets, or remove it from the extension to inherit the host value"]];
    }

    NSString *hostGroup = [self trimmedStringForKey:kAppGroupsKey inBundle:bundle];
    NSString *appexGroup = [self trimmedStringForKey:kAppGroupsKey inBundle:appexBundle];
    if (hostGroup && appexGroup && ![hostGroup isEqualToString:appexGroup]) {
        [findings addObject:[PWIntegrationFinding findingWithRule:@"nse.appgroup.mismatch"
                                                         severity:PWIntegrationSeverityWarning
                                                          message:[NSString stringWithFormat:@"PW_APP_GROUPS_NAME differs between app ('%@') and %@ ('%@')", hostGroup, appexName, appexGroup]
                                                          fixHint:@"Use the same app group name in both targets"]];
    }

    if (findings.count == 0) {
        [findings addObject:[PWIntegrationFinding findingWithRule:@"nse.present"
                                                         severity:PWIntegrationSeverityOK
                                                          message:[NSString stringWithFormat:@"Notification Service Extension: %@", appexName]
                                                          fixHint:nil]];
    }
    return findings;
}

+ (NSBundle *)notificationServiceExtensionBundleIn:(NSBundle *)bundle {
    NSURL *plugInsURL = bundle.builtInPlugInsURL;
    if (!plugInsURL) {
        return nil;
    }
    NSArray<NSURL *> *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:plugInsURL
                                                                includingPropertiesForKeys:nil
                                                                                   options:0
                                                                                     error:nil];
    for (NSURL *itemURL in contents) {
        if (![itemURL.pathExtension isEqualToString:@"appex"]) {
            continue;
        }
        NSBundle *appexBundle = [NSBundle bundleWithURL:itemURL];
        NSDictionary *extensionInfo = [appexBundle objectForInfoDictionaryKey:@"NSExtension"];
        if (![extensionInfo isKindOfClass:[NSDictionary class]]) {
            continue;
        }
        NSString *pointIdentifier = extensionInfo[@"NSExtensionPointIdentifier"];
        if ([pointIdentifier isKindOfClass:[NSString class]] &&
            [pointIdentifier isEqualToString:@"com.apple.usernotifications.service"]) {
            return appexBundle;
        }
    }
    return nil;
}

#endif

#pragma mark - Report

+ (void)logReport:(NSArray<PWIntegrationFinding *> *)findings {
    if (findings.count == 0) {
        return;
    }

    PWIntegrationSeverity maxSeverity = PWIntegrationSeverityOK;
    NSMutableString *report = [NSMutableString stringWithString:@"\nIntegration Health Check\n"];
    for (PWIntegrationFinding *finding in findings) {
        [report appendFormat:@" %@ %@\n", [self markerForSeverity:finding.severity], finding.message];
        if (finding.fixHint && finding.severity != PWIntegrationSeverityOK) {
            [report appendFormat:@"   Fix: %@\n", finding.fixHint];
        }
        if (finding.severity > maxSeverity) {
            maxSeverity = finding.severity;
        }
    }

    [PushwooshLog pushwooshLog:[self logLevelForSeverity:maxSeverity] className:self message:report];
}

+ (NSString *)markerForSeverity:(PWIntegrationSeverity)severity {
    switch (severity) {
        case PWIntegrationSeverityOK: return @"✓";
        case PWIntegrationSeverityInfo: return @"ℹ";
        case PWIntegrationSeverityWarning: return @"⚠";
        case PWIntegrationSeverityError: return @"✗";
    }
    return @"•";
}

+ (PUSHWOOSH_LOG_LEVEL)logLevelForSeverity:(PWIntegrationSeverity)severity {
    switch (severity) {
        case PWIntegrationSeverityError: return PW_LL_ERROR;
        case PWIntegrationSeverityWarning: return PW_LL_WARN;
        default: return PW_LL_INFO;
    }
}

@end
