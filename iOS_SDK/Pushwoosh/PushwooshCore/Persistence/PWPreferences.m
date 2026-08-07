//
//  PWPreferences.m
//  PushwooshCore
//
//  Created by André Kis on 07.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PWPreferences.h"
#import "PWConfig.h"
#import "PWUtils.h"
#import "Constants.h"
#import "PWSdkStateProvider.h"
#import "PWModuleResolution.h"
#import <PushwooshCore/PushwooshLog.h>

/// The bridge itself is cross-platform; only the inbox half of it is iOS-only.
#import <PushwooshCore/PWManagerBridge.h>

#if TARGET_OS_IOS
#import <PushwooshCore/PWInboxBridge.h>
#endif

static NSString *const KeyAppId = @"Pushwoosh_APPID";
static NSString *const KeyInfoPlistAppId = @"Pushwoosh_INFO_PLIST_APPID";
static NSString *const KeyAppName = @"Pushwoosh_APPNAME";
static NSString *const KeyPushToken = @"PWPushUserId";
static NSString *const KeyVoipPushToken = @"PWVoipPushUserId";
static NSString *const KeyPushTvToken = @"PWPushTvUserId";
static NSString *const KeyApiToken = @"PWApiToken";
static NSString *const KeyUserId = @"PWInAppUserId";
static NSString *const KeyLastRegTime = @"PWLastRegTime";
static NSString *const KeyLastStatusMask = @"PWLastStatusMask";
static NSString *const KeyPushwooshCategories = @"pushwooshIOSCategories";
static NSString *const KeyBaseUrl = @"Pushwoosh_BASEURL";
static NSString *const KeyLastSendAttrDate = @"PWLastSetAttrRegTime";
static NSString *const KeyLastRegisterUserDate = @"PWLastRegisterUserTime";
static NSString *const KeyDeviceId = @"PWDeviceHwid";
static NSString *const KeyLogLevel = @"PWLogLevel";
static NSString *const KeyRegistrationEverOccured = @"PWRegistrationEverOccured";
static NSString *const KeyLanguage = @"Pushwoosh_Language";
static NSString *const KeyIsLoggerAvailable = @"Logger_available";
static NSString *const KeyIsServerCommunicationEnabled = @"Server_communication_enabled";
static NSString *const KeyAdvertisingId = @"PWAdvertisingId";
static NSString *const KeyLastKnockTriggerTimestamp = @"PWKnockPatternDetectorLastTriggerTimestamp";
static NSString *const KeyActiveApplication = @"Pushwoosh_ACTIVE_APPLICATION";
static NSString *const KeyEffectiveApplication = @"Pushwoosh_EFFECTIVE_APPLICATION";
static NSString *const kPWActiveUpdatedAtField = @"updatedAt";

NSString * const kPWActiveApplicationAppCodeKey = @"appCode";
NSString * const kPWActiveApplicationBaseUrlKey = @"baseUrl";

/// Flag to prevent recursive calls during singleton initialization
static BOOL _isInitializing = NO;

@interface PWPreferences ()

@property (nonatomic, strong) NSObject *lock;

/// Serializes every writer of the (appCode, baseUrl) pair. Lock order is always `switchLock` -> `lock`;
/// callouts to foreign code (inbox reset, KVO, notifications, unregister) run outside it. See decisions.md ADR-10.
@property (nonatomic, strong) NSObject *switchLock;

/// Suppresses the App Group mirror while the pair is half-applied. Access only under `switchLock`.
@property (nonatomic, assign) BOOL isApplyingSwitch;
@property (nonatomic) NSUserDefaults *defaults;

@end

@implementation PWPreferences

@synthesize appCode = _appCode;
@synthesize appName = _appName;
@synthesize pushToken = _pushToken;
@synthesize voipPushToken = _voipPushToken;
@synthesize pushTvToken = _pushTvToken;
@synthesize apiToken = _apiToken;
@synthesize userId = _userId;
@synthesize lastRegTime = _lastRegTime;
@synthesize lastStatusMask = _lastStatusMask;
@synthesize categories = _categories;
@synthesize baseUrl = _baseUrl;
@synthesize isLoggerActive = _isLoggerActive;
@synthesize lastRegisterUserDate = _lastRegisterUserDate;
@synthesize hwid = _hwid;
@synthesize logLevel = _logLevel;
@synthesize language = _language;
@synthesize isServerCommunicationEnabled = _isServerCommunicationEnabled;
@synthesize customTags = _customTags;
@synthesize advertisingId = _advertisingId;
@synthesize lastKnockTriggerTimestamp = _lastKnockTriggerTimestamp;

+ (BOOL)isInitializing {
    return _isInitializing;
}

- (instancetype)init {
    _isInitializing = YES;

    self = [super init];
    if (self) {
        [[NSUserDefaults standardUserDefaults] synchronize];

        _lock = [NSObject new];
        _switchLock = [NSObject new];

        NSString *previosHWID = [[NSUserDefaults standardUserDefaults] objectForKey:KeyDeviceId];

        NSString *persistentHWID = [self getPersistentHWIDIfAvailable];
        if (persistentHWID) {
            _hwid = persistentHWID;
        } else {
            _hwid = [PWUtils uniqueGlobalDeviceIdentifier];
        }

        if (![PWUtils isValidHwid:previosHWID] ) {
            [self saveCurrentHWIDtoUserDefaults];
        } else if (![_hwid isEqualToString:previosHWID]) {
            _previosHWID = previosHWID;
        }

        [self setAppCode:[PWPreferences readAppId]];

        _appName = [PWPreferences readAppName];
        _pushToken = [[NSUserDefaults standardUserDefaults] objectForKey:KeyPushToken];
        _voipPushToken = [[NSUserDefaults standardUserDefaults] objectForKey:KeyVoipPushToken];
        _pushTvToken = [[NSUserDefaults standardUserDefaults] objectForKey:KeyPushTvToken];

        if ([[PWConfig config] appGroupsName]) {
            _defaults = [[NSUserDefaults alloc] initWithSuiteName:[[PWConfig config] appGroupsName]];
            NSString *prevSavedUserId = [[NSUserDefaults standardUserDefaults] objectForKey:KeyUserId];
            if (prevSavedUserId) {
                _userId = prevSavedUserId;
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyUserId];
                [_defaults setObject:_userId forKey:KeyUserId];
            } else {
                if ([_defaults objectForKey:KeyUserId]) {
                    _userId = [_defaults objectForKey:KeyUserId];
                } else {
                    _userId = _hwid;
                }
            }
        } else {
            NSString *userId = [[NSUserDefaults standardUserDefaults] objectForKey:KeyUserId];
            if (userId) {
                _userId = userId;
            } else {
                _userId = _hwid;
            }
        }

        _lastRegTime = [[NSUserDefaults standardUserDefaults] objectForKey:KeyLastRegTime];
        _lastStatusMask = [[[NSUserDefaults standardUserDefaults] objectForKey:KeyLastStatusMask] integerValue];
        _lastRegisterUserDate = [[NSUserDefaults standardUserDefaults] objectForKey:KeyLastRegisterUserDate];

        _categories = [[NSUserDefaults standardUserDefaults] objectForKey:KeyPushwooshCategories];
        _logLevel = [PWPreferences readLogLevel];
        _baseUrl = nil;

        _isLoggerActive = [[NSUserDefaults standardUserDefaults] boolForKey:KeyIsLoggerAvailable];

        NSNumber *registrationOccured = [[NSUserDefaults standardUserDefaults] objectForKey:KeyRegistrationEverOccured];

        if (registrationOccured) {
            _registrationEverOccured = registrationOccured.boolValue;
        }

        _language = [[NSUserDefaults standardUserDefaults] objectForKey:KeyLanguage];

        if (!_language) {
            _language = [PWUtils preferredLanguage];
        }

        if ([[NSUserDefaults standardUserDefaults] objectForKey:KeyIsServerCommunicationEnabled]) {
            _isServerCommunicationEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:KeyIsServerCommunicationEnabled];
        } else {
            _isServerCommunicationEnabled = [PWConfig config].allowServerCommunication;
        }

        _showForegroundNotifications = [PWConfig config].showAlert;

        _advertisingId = [[NSUserDefaults standardUserDefaults] objectForKey:KeyAdvertisingId];

        _lastKnockTriggerTimestamp = [[NSUserDefaults standardUserDefaults] doubleForKey:KeyLastKnockTriggerTimestamp];
    }

    _isInitializing = NO;

    return self;
}

+ (instancetype)preferences {
    static PWPreferences *instance = nil;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        instance = [PWPreferences new];
    });

    return instance;
}

- (void)resetApplicationSetting {
    [self resetInboxForApplicationChange];
    [self resetApplicationSettingExceptInbox];
}

/// Split out of the reset: archives files to disk synchronously, so the switch path calls it
/// after leaving `switchLock` instead of holding the lock for the write.
- (void)resetInboxForApplicationChange {
#if TARGET_OS_IOS
    [[PWManagerBridge shared].inboxBridge resetApplication];
#endif
}

- (void)resetApplicationSettingExceptInbox {
    [self.class resetCache];
    _baseUrl = nil;
    _lastRegTime = nil;
    _lastRegisterUserDate = nil;
    _categories = nil;
    [self setAdvertisingId:nil];
}

+ (void)resetCache {
    if (![self hasActiveApplicationRecord]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyBaseUrl];
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyLastRegTime];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyLastSendAttrDate];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyLastRegisterUserDate];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyPushwooshCategories];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyAdvertisingId];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyLastKnockTriggerTimestamp];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)language {
    @synchronized(_lock) {
        return _language;
    }
}

- (void)setLanguage:(NSString *)language {
    if (!language || language.length != 2 ) {
        language = [PWUtils preferredLanguage];
    }

    @synchronized(_lock) {
        _language = [language copy];
    }

    [[NSUserDefaults standardUserDefaults] setObject:language forKey:KeyLanguage];
    [[NSUserDefaults standardUserDefaults] synchronize];

    self.lastRegTime = NSDate.distantPast;
}

- (void)setAppName:(NSString *)appName {
    if (!appName)
        return;

    @synchronized(_lock) {
        _appName = [appName copy];
    }

    [[NSUserDefaults standardUserDefaults] setObject:appName forKey:KeyAppName];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)appName {
    @synchronized(_lock) {
        return [_appName copy];
    }
}

- (void)setPushToken:(NSString *)pushToken {
    @synchronized(_lock) {
        _pushToken = [pushToken copy];
    }

    [[NSUserDefaults standardUserDefaults] setObject:pushToken forKey:KeyPushToken];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)pushToken {
    @synchronized(_lock) {
        return [_pushToken copy];
    }
}

- (void)setVoipPushToken:(NSString *)voipPushToken {
    @synchronized(_lock) {
        _voipPushToken = [voipPushToken copy];
    }

    [[NSUserDefaults standardUserDefaults] setObject:voipPushToken forKey:KeyVoipPushToken];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)voipPushToken {
    @synchronized(_lock) {
        return [_voipPushToken copy];
    }
}

- (void)setPushTvToken:(NSString *)pushTvToken {
    @synchronized(_lock) {
        _pushTvToken = [pushTvToken copy];
    }

    [[NSUserDefaults standardUserDefaults] setObject:pushTvToken forKey:KeyPushTvToken];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)pushTvToken {
    @synchronized(_lock) {
        return [_pushTvToken copy];
    }
}

- (void)setApiToken:(NSString *)apiToken {
    @synchronized(_lock) {
        _apiToken = [apiToken copy];
    }

    [[NSUserDefaults standardUserDefaults] setObject:apiToken forKey:KeyApiToken];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)apiToken {
    @synchronized(_lock) {
        return [_apiToken copy];
    }
}

- (void)setLastRegTime:(NSDate *)lastRegTime {
    @synchronized(_lock) {
        _lastRegTime = [lastRegTime copy];
    }

    [[NSUserDefaults standardUserDefaults] setObject:lastRegTime forKey:KeyLastRegTime];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSDate *)lastRegTime {
    @synchronized(_lock) {
        return [_lastRegTime copy];
    }
}

- (void)setLastStatusMask:(NSInteger)lastStatusMask {
    @synchronized (_lock) {
        _lastStatusMask = lastStatusMask;
    }
    [[NSUserDefaults standardUserDefaults] setInteger:lastStatusMask forKey:KeyLastStatusMask];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSInteger)lastStatusMask {
    @synchronized (_lock) {
        return _lastStatusMask;
    }
}

- (void)setUserId:(NSString *)userId {
    if (!userId) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"userId cannot be nil"];
        return;
    }

    @synchronized(_lock) {
        _userId = [userId copy];
    }

    if ([[PWConfig config] appGroupsName]) {
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:[[PWConfig config] appGroupsName]];
        [_defaults setObject:userId forKey:KeyUserId];
    } else {
        [[NSUserDefaults standardUserDefaults] setObject:userId forKey:KeyUserId];
    }
}

- (NSString *)userId {
    @synchronized(_lock) {
        return [_userId copy];
    }
}

- (void)setCategories:(NSArray *)categories {
    if (![PWPreferences verifyObject:categories]) {
        [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:[NSString stringWithFormat:@"Unable to save categories: %@", categories]];
        return;
    }

    @synchronized(_lock) {
        _categories = [categories copy];
    }

    [[NSUserDefaults standardUserDefaults] setObject:categories forKey:KeyPushwooshCategories];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray *)categories {
    @synchronized(_lock) {
        return [_categories copy];
    }
}

- (NSString *)baseUrl {
    @synchronized(_lock) {
        if (_baseUrl == nil) {
            _baseUrl = [[self readBaseUrl] copy];
        }
        return _baseUrl;
    }
}

- (void)setBaseUrl:(NSString *)baseUrl {
    [self updateBaseUrl:baseUrl];
}

/// Takes `switchLock` so a server-driven rotation cannot land mid-transaction and leave the new
/// application code pointing at a foreign host. Recursive, so the transaction's own call passes through.
- (NSString *)updateBaseUrl:(NSString *)rawUrl {
    NSString *normalized = [self.class normalizeBaseUrl:rawUrl];
    if (normalized == nil) {
        return nil;
    }

    BOOL didWrite = NO;
    @synchronized (_switchLock) {
        @synchronized(_lock) {
            if (![_baseUrl isEqualToString:normalized]) {
                _baseUrl = [normalized copy];
                [[NSUserDefaults standardUserDefaults] setObject:normalized forKey:KeyBaseUrl];
                [[NSUserDefaults standardUserDefaults] synchronize];
                didWrite = YES;
            }
        }
    }
    if (didWrite) {
        [self mirrorEffectiveApplicationIntoAppGroup];
        [PushwooshLog pushwooshLog:PW_LL_INFO
                         className:[PWPreferences class]
                           message:[NSString stringWithFormat:@"Update base URL: %@", normalized]];
    }
    return normalized;
}

/// The reset counterpart of `-updateBaseUrl:`, so the switch transaction states its intent instead of
/// clearing the in-memory value and the defaults key inline.
- (void)clearEffectiveBaseUrl {
    @synchronized(_lock) {
        _baseUrl = nil;
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyBaseUrl];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)normalizeBaseUrl:(NSString *)rawUrl {
    NSString *rejection = nil;
    NSString *normalized = [self normalizeBaseUrl:rawUrl rejectionReason:&rejection];
    if (normalized == nil) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:[PWPreferences class]
                           message:[NSString stringWithFormat:@"Reject base URL: %@", rejection]];
    }
    return normalized;
}

/// Silent variant for validate-on-read callers. `outReason` (may be NULL) never names the raw input,
/// only the parsed host, so a spoofed URL cannot produce a legitimate-looking log line.
+ (NSString *)normalizeBaseUrl:(NSString *)rawUrl rejectionReason:(NSString **)outReason {
    NSString *trimmed = [rawUrl stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSURL *parsed = nil;
    NSString *reason = nil;
    NSString *normalized = nil;

    if (rawUrl.length == 0) {
        reason = @"empty value";
    } else if (trimmed.length == 0) {
        reason = @"whitespace-only value";
    } else if ([trimmed rangeOfCharacterFromSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]].location != NSNotFound) {
        reason = @"contains whitespace";
    } else if (![trimmed hasPrefix:@"https://"] && ![trimmed hasPrefix:@"http://"]) {
        reason = @"scheme must be http(s)://";
    } else if ((parsed = [NSURL URLWithString:trimmed]) == nil || parsed.host.length == 0) {
        reason = @"malformed URL";
    } else if (parsed.user != nil || parsed.password != nil) {
        reason = [NSString stringWithFormat:@"URL carries userinfo, real host would be \"%@\"", parsed.host];
    } else {
        normalized = [trimmed hasSuffix:@"/"] ? trimmed : [trimmed stringByAppendingString:@"/"];
    }

    if (normalized == nil && outReason != NULL) {
        *outReason = reason;
    }
    return normalized;
}

- (BOOL)isLoggerActive {
    @synchronized (_lock) {
        return _isLoggerActive;
    }
}

- (void)setIsLoggerActive:(BOOL)isLoggerActive {
    @synchronized (_lock) {
        _isLoggerActive = isLoggerActive;
    }

    [[NSUserDefaults standardUserDefaults] setBool:isLoggerActive forKey:KeyIsLoggerAvailable];
}

- (BOOL)isServerCommunicationEnabled {
    @synchronized (_lock) {
        return _isServerCommunicationEnabled;
    }
}

- (void)setIsServerCommunicationEnabled:(BOOL)isEnabled {
    @synchronized (_lock) {
        _isServerCommunicationEnabled = isEnabled;
    }

    [[NSUserDefaults standardUserDefaults] setBool:isEnabled forKey:KeyIsServerCommunicationEnabled];
}

- (NSDate *)lastRegisterUserDate {
    @synchronized(_lock) {
        return _lastRegisterUserDate;
    }
}

- (void)setLastRegisterUserDate:(NSDate *)lastRegisterUserDate {
    @synchronized(_lock) {
        _lastRegisterUserDate = [lastRegisterUserDate copy];
    }

    [[NSUserDefaults standardUserDefaults] setObject:lastRegisterUserDate forKey:KeyLastRegisterUserDate];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (unsigned int)logLevel {
    return _logLevel;
}

- (void)setLogLevel:(unsigned int)logLevel {
    _logLevel = logLevel;

    [[NSUserDefaults standardUserDefaults] setObject:@(logLevel) forKey:KeyLogLevel];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)hwid {
    @synchronized(_lock) {
        return [_hwid copy];
    }
}

- (void)setCustomTags:(NSDictionary *)customTags {
    _customTags = nil;

    @synchronized (_lock) {
        _customTags = [customTags copy];
    }
}

- (NSDictionary *)customTags {
    @synchronized(_lock) {
        return [_customTags copy];
    }
}

- (NSString *)advertisingId {
    @synchronized(_lock) {
        return [_advertisingId copy];
    }
}

- (void)setAdvertisingId:(NSString *)advertisingId {
    @synchronized(_lock) {
        _advertisingId = [advertisingId copy];
    }

    if (advertisingId) {
        [[NSUserDefaults standardUserDefaults] setObject:advertisingId forKey:KeyAdvertisingId];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyAdvertisingId];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSTimeInterval)lastKnockTriggerTimestamp {
    @synchronized(_lock) {
        return _lastKnockTriggerTimestamp;
    }
}

- (void)setLastKnockTriggerTimestamp:(NSTimeInterval)lastKnockTriggerTimestamp {
    @synchronized(_lock) {
        _lastKnockTriggerTimestamp = lastKnockTriggerTimestamp;
    }

    [[NSUserDefaults standardUserDefaults] setDouble:lastKnockTriggerTimestamp forKey:KeyLastKnockTriggerTimestamp];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)readAppName {
    NSString *appName = [PWConfig config].appName;
    if (!appName)
        appName = [[NSUserDefaults standardUserDefaults] objectForKey:KeyAppName];

    if (!appName)
        appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];

    if (!appName)
        appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];

    if (!appName) {
        appName = @"";
    }

    return appName;
}

/// Resolution order: effective endpoint (`Pushwoosh_BASEURL`, server-rotatable) -> the integrator's
/// recorded choice -> Info.plist -> the app-code-derived template.
- (NSString *)readBaseUrl {
    NSString *persisted = [[NSUserDefaults standardUserDefaults] objectForKey:KeyBaseUrl];

    if (persisted.length > 0) {
        NSURL *parsed = [NSURL URLWithString:persisted];
        if ([parsed.host isEqualToString:@"cp.pushwoosh.com"]) {
            [PushwooshLog pushwooshLog:PW_LL_INFO
                             className:[PWPreferences class]
                               message:@"Discarding persisted legacy base URL (cp.pushwoosh.com)"];
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyBaseUrl];
            [[NSUserDefaults standardUserDefaults] synchronize];
            persisted = nil;
        }
    }

    if (persisted.length > 0) {
        return persisted;
    }

    NSString *recordBaseUrl = [self.class readActiveApplicationRecord][kPWActiveApplicationBaseUrlKey];
    if (recordBaseUrl.length > 0) {
        return recordBaseUrl;
    }

    return [self defaultBaseUrl];
}

- (NSString *)defaultBaseUrl {
    NSString *serviceAddressUrl = [PWConfig config].requestUrl;
    if (serviceAddressUrl.length > 0) {
        return serviceAddressUrl;
    }

    NSString *appCode;
    @synchronized(_lock) {
        appCode = [_appCode copy];
    }
    if (appCode == nil) {
        appCode = [self.class readAppId];
    }
    if (appCode.length == 0 || [appCode rangeOfString:@"."].location != NSNotFound) {
        return nil;
    }
    return [NSString stringWithFormat:kBaseDefaultURLFormat, appCode];
}

+ (unsigned int)readLogLevel {
    NSNumber *logLevelObject = [[NSUserDefaults standardUserDefaults] objectForKey:KeyLogLevel];
    if (![logLevelObject isKindOfClass: [NSNumber class]]) {
        logLevelObject = @([PWConfig config].logLevel);
    }

    return (unsigned int)logLevelObject.integerValue;
}

- (void)setRegistrationEverOccured:(BOOL)registrationEverOccured {
    _registrationEverOccured = registrationEverOccured;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:KeyRegistrationEverOccured];
}

#pragma mark - AppCode

- (void)setAppCode:(NSString *)appCode {
    if (appCode != nil && [appCode rangeOfString:@"."].location != NSNotFound) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:[PWPreferences class]
                           message:@"Application id format with '.' is deprecated. Please contact Pushwoosh support."];
        return;
    }

    [self announceUpcomingApplicationChangeIfCodeMoves:appCode];

    /// Second writer of the (appCode, baseUrl) pair — serialized against the switch transaction,
    /// which never calls this setter (it applies the code via `-applyAppCode:resetInbox:`).
    NSDictionary *vacatedApplication = nil;
    BOOL shouldResetInbox = NO;
    @synchronized (_switchLock) {
        vacatedApplication = [self applyAppCode:appCode resetInbox:&shouldResetInbox];
    }

    /// Callouts to foreign code (inbox reset, notifications, unregister) run outside every lock.
    if (shouldResetInbox) {
        [self resetInboxForApplicationChange];
    }

    if (appCode.length > 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kPWAppCodeUpdatedNotification object:nil];
    }

    /// This setter moves the application too (`initializeWithAppCode:` lands here), so it posts the
    /// same isolation notification as the switch transaction.
    if (vacatedApplication != nil) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kPWActiveApplicationChangedNotification
                                                            object:nil
                                                          userInfo:@{ kPWActiveApplicationChangedAppCodeChangedKey: @(YES) }];
    }

    [self unregisterFromVacatedApplication:vacatedApplication];
}

/// Posted before the code moves so the pending `setTags` window drains under the previous application.
/// Decided outside `switchLock` on purpose; `kPWActiveApplicationChangedNotification` is the backstop.
- (void)announceUpcomingApplicationChangeIfCodeMoves:(NSString *)incomingAppCode {
    if (incomingAppCode.length == 0) {
        return;
    }

    NSString *currentAppCode = [self appCode];
    if (currentAppCode.length == 0 || [currentAppCode isEqualToString:incomingAppCode]) {
        return;
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:kPWActiveApplicationWillChangeNotification object:nil];
}

/// Pays the KVO + `kPWAppCodeUpdatedNotification` debt of `-applyAppCode:resetInbox:` (which writes the
/// ivar without KVO), after the transaction's critical section so observers never run under `switchLock`.
- (void)announceAppCodeChange {
    if ([self appCode].length == 0) {
        return;
    }

    [self willChangeValueForKey:@"appCode"];
    [self didChangeValueForKey:@"appCode"];

    [[NSNotificationCenter defaultCenter] postNotificationName:kPWAppCodeUpdatedNotification object:nil];
}

/// Returns the pair of the application this call is leaving (for the caller's unregister), or nil when
/// nothing was vacated — first launch, same code, empty code, initialization, or a switch transaction.
- (NSDictionary *)applyAppCode:(NSString *)appCode resetInbox:(BOOL *)outResetInbox {
    NSString *previousAppCode;
    @synchronized (_lock) {
        previousAppCode = [_appCode copy];
    }
    /// Read before the reset below clears the effective URL — the unregister must reach the previous host.
    NSString *previousBaseUrl = previousAppCode.length > 0 ? [self baseUrl] : nil;

    @synchronized(_lock) {
        _appCode = [appCode copy];

        if ([PWPreferences checkAppCodeforChanges:appCode]) {
            [self resetApplicationSettingExceptInbox];
            if (outResetInbox != NULL) {
                *outResetInbox = YES;
            }
        }
    }

    [[NSUserDefaults standardUserDefaults] setObject:appCode forKey:KeyAppId];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSString *appGroupsName = [[PWConfig config] appGroupsName];
    if (appGroupsName.length > 0) {
        NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:appGroupsName];
        if (appCode.length > 0) {
            [shared setObject:appCode forKey:KeyAppId];
        } else {
            [shared removeObjectForKey:KeyAppId];
        }
    }

    NSDictionary *record = [self.class readActiveApplicationRecord];
    NSString *recordBaseUrl = record[kPWActiveApplicationBaseUrlKey];
    if (record != nil && appCode.length > 0 && ![record[kPWActiveApplicationAppCodeKey] isEqualToString:appCode]) {
        [self writeActiveApplicationRecordWithAppCode:appCode baseUrl:nil];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyBaseUrl];
        [[NSUserDefaults standardUserDefaults] synchronize];
        @synchronized(_lock) {
            _baseUrl = nil;
        }
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:[PWPreferences class]
                           message:[NSString stringWithFormat:@"setAppCode: changed the application to %@, so the endpoint %@ that was selected for the previous one was dropped and the default is used instead. Use Pushwoosh.configure.setAppCode(_:baseUrl:) to move an application and its endpoint together.", appCode, recordBaseUrl.length > 0 ? recordBaseUrl : @"(default)"]];
        recordBaseUrl = nil;
    }

    NSString *appCodeSnapshot;
    NSString *currentBaseUrl;
    @synchronized(_lock) {
        appCodeSnapshot = [_appCode copy];
        currentBaseUrl = [_baseUrl copy];
    }
    if (appCodeSnapshot.length > 0 && currentBaseUrl.length == 0 && recordBaseUrl.length == 0) {
        NSString *defaultUrl = [self defaultBaseUrl];
        if (defaultUrl.length > 0) {
            NSString *persisted = [[NSUserDefaults standardUserDefaults] objectForKey:KeyBaseUrl];
            if (persisted.length == 0) {
                [self updateBaseUrl:defaultUrl];
            }
        }
    }

    [self mirrorEffectiveApplicationIntoAppGroup];

    if (_isApplyingSwitch || _isInitializing) {
        return nil;
    }
    if (appCode.length == 0 || previousAppCode.length == 0 || [previousAppCode isEqualToString:appCode]) {
        return nil;
    }

    return @{ kPWActiveApplicationAppCodeKey: previousAppCode,
              kPWActiveApplicationBaseUrlKey: previousBaseUrl ?: @"" };
}

/// Every path that changes the application code unregisters from the one being left (matches Android).
/// Skipped when the previous host cannot be resolved — that traffic must not reach the current host.
- (void)unregisterFromVacatedApplication:(NSDictionary<NSString *, NSString *> *)vacatedApplication {
    NSString *appCode = vacatedApplication[kPWActiveApplicationAppCodeKey];
    if (appCode.length == 0) {
        return;
    }

    NSString *baseUrl = vacatedApplication[kPWActiveApplicationBaseUrlKey];
    if (baseUrl.length == 0) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:[PWPreferences class]
                           message:[NSString stringWithFormat:@"setAppCode: the API endpoint of the previous application %@ could not be resolved, so the device was not unregistered from it. It may keep receiving that application's pushes.", appCode]];
        return;
    }

    [[PWManagerBridge shared] unregisterFromApplicationWithAppCode:appCode baseUrl:baseUrl];
}

- (NSString *)appCode {
    @synchronized(_lock) {
        return [_appCode copy];
    }
}

+ (BOOL)checkAppCodeforChanges:(NSString *)appCode {
    NSString *appid = [[NSUserDefaults standardUserDefaults] objectForKey:KeyAppId];
    if (appid != nil && ![appid isEqualToString:appCode]) {
        return YES;
    } else {
        return NO;
    }
}

+ (NSString *)readAppId {
    NSString *recordAppCode = [self readActiveApplicationRecord][kPWActiveApplicationAppCodeKey];
    if (recordAppCode.length > 0) {
        return recordAppCode;
    }

    NSString *appId = [self developAppCodeIfNeeded];

    if (!appId) {
        appId = [self readProductionAppCodeAndUpdateIfNeeded];
    }

    return appId;
}

+ (NSString *)developAppCodeIfNeeded {
    BOOL productionAPS = [PWUtils getAPSProductionStatus:NO];
    NSString *appId = nil;
    if (!productionAPS) {
        appId = [PWConfig config].appIdDev;
    }
    return appId;
}

+ (NSString *)readProductionAppCodeAndUpdateIfNeeded {
    NSString *infoPlistAppCode = [PWConfig config].appId;
    NSString *saveInfoPlistAppCode = [[NSUserDefaults standardUserDefaults] objectForKey:KeyInfoPlistAppId];
    NSString *userDefaultsAppCode = [[NSUserDefaults standardUserDefaults] objectForKey:KeyAppId];

    if (userDefaultsAppCode && infoPlistAppCode) {
         if (![infoPlistAppCode isEqualToString:saveInfoPlistAppCode]) {
            if (![userDefaultsAppCode isEqualToString:infoPlistAppCode]) {
                [self resetCache];
            }
            [[NSUserDefaults standardUserDefaults] setObject:infoPlistAppCode forKey:KeyInfoPlistAppId];
            [[NSUserDefaults standardUserDefaults] setObject:infoPlistAppCode forKey:KeyAppId];
            [[NSUserDefaults standardUserDefaults] synchronize];
            return infoPlistAppCode;
        } else {
            return userDefaultsAppCode;
        }
    } else if (userDefaultsAppCode) {
        return userDefaultsAppCode;
    } else if (infoPlistAppCode) {
        [[NSUserDefaults standardUserDefaults] setObject:infoPlistAppCode forKey:KeyInfoPlistAppId];
        [[NSUserDefaults standardUserDefaults] synchronize];
        return infoPlistAppCode;
    }

    NSString *sharedAppCode = [self readSharedAppCode];
    if (sharedAppCode.length > 0) {
        return sharedAppCode;
    }
    return @"";
}

+ (NSString *)readSharedAppCode {
    NSString *appGroupsName = [[PWConfig config] appGroupsName];
    if (appGroupsName.length == 0) {
        return nil;
    }
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:appGroupsName];
    NSString *value = [shared objectForKey:KeyAppId];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (BOOL)hasAppCode {
    NSString *code = self.appCode;
    if (code && code.length > 0) {
        return YES;
    }

    return NO;
}

+ (BOOL)verifyObject:(id)object {
    if (!object) {
        return YES;
    }

    BOOL result = YES;
    if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = (NSArray *)object;
        for (id item in array) {
            result = result && [PWPreferences verifyObject:item];
        }
    } else if ([object isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)object;
        for (NSString *key in dict) {
            result = result && [PWPreferences verifyObject:key];
            result = result && [PWPreferences verifyObject:dict[key]];
        }
    } else if ([object isKindOfClass:[NSData class]] ||
               [object isKindOfClass:[NSString class]] ||
               [object isKindOfClass:[NSNumber class]] ||
               [object isKindOfClass:[NSDate class]]) {
        result = YES;
    } else {
        result = NO;
    }

    return result;
}

- (void)saveCurrentHWIDtoUserDefaults {
    _previosHWID = nil;
    [[NSUserDefaults standardUserDefaults] setObject:_hwid forKey:KeyDeviceId];
}

#pragma mark - Active application record

/// A value the switch would have rejected makes the whole record absent; a URL that merely
/// needs normalizing is returned corrected.
+ (NSDictionary *)validatedActiveApplicationRecord:(id)raw {
    if (![raw isKindOfClass:[NSDictionary class]]) {
        return nil;
    }

    NSDictionary *record = (NSDictionary *)raw;
    id appCode = record[kPWActiveApplicationAppCodeKey];
    if (![appCode isKindOfClass:[NSString class]] || [(NSString *)appCode length] == 0) {
        return nil;
    }
    if ([(NSString *)appCode rangeOfString:@"."].location != NSNotFound) {
        [self logMalformedActiveApplicationRecordOnce:@"the application code has the deprecated '.' format"];
        return nil;
    }

    id baseUrl = record[kPWActiveApplicationBaseUrlKey];
    if (baseUrl == nil) {
        return record;
    }
    if (![baseUrl isKindOfClass:[NSString class]] || [(NSString *)baseUrl length] == 0) {
        return nil;
    }

    NSString *rejection = nil;
    NSString *normalized = [self normalizeBaseUrl:(NSString *)baseUrl rejectionReason:&rejection];
    if (normalized == nil) {
        [self logMalformedActiveApplicationRecordOnce:rejection];
        return nil;
    }
    if ([normalized isEqualToString:(NSString *)baseUrl]) {
        return record;
    }

    NSMutableDictionary *corrected = [record mutableCopy];
    corrected[kPWActiveApplicationBaseUrlKey] = normalized;
    return corrected;
}

+ (void)logMalformedActiveApplicationRecordOnce:(NSString *)reason {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:[PWPreferences class]
                           message:[NSString stringWithFormat:@"Ignoring the stored active-application record: %@. Call Pushwoosh.configure.setAppCode(_:baseUrl:) again to re-select an application.", reason]];
    });
}

/// Reads the host app's own `standardUserDefaults` only — preferring the App Group suite here
/// would let any process in the group redirect the host.
+ (NSDictionary *)readActiveApplicationRecord {
    return [self validatedActiveApplicationRecord:[[NSUserDefaults standardUserDefaults] objectForKey:KeyActiveApplication]];
}

+ (BOOL)hasActiveApplicationRecord {
    return [self readActiveApplicationRecord] != nil;
}

- (NSString *)selectedBaseUrl {
    return [self.class readActiveApplicationRecord][kPWActiveApplicationBaseUrlKey];
}

/// One builder for both stored pairs (the integrator's record and the effective mirror), so the two
/// can never disagree on keys or the timestamp field.
+ (NSDictionary *)pairRecordWithAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl {
    NSMutableDictionary *record = [NSMutableDictionary new];
    record[kPWActiveApplicationAppCodeKey] = appCode;
    if (baseUrl.length > 0) {
        record[kPWActiveApplicationBaseUrlKey] = baseUrl;
    }
    record[kPWActiveUpdatedAtField] = @([[NSDate date] timeIntervalSince1970]);
    return record;
}

- (void)writeActiveApplicationRecordWithAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl {
    NSDictionary *record = [self.class pairRecordWithAppCode:appCode baseUrl:baseUrl];

    [[NSUserDefaults standardUserDefaults] setObject:record forKey:KeyActiveApplication];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSString *appGroupsName = [[PWConfig config] appGroupsName];
    if (appGroupsName.length > 0) {
        NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:appGroupsName];
        [shared setObject:record forKey:KeyActiveApplication];
        [shared synchronize];
    }
}

/// Publishes the effective pair for the extension. Skipped mid-switch (the transaction mirrors once
/// at the end itself), under `switchLock` so a racing rotation never publishes a half-applied pair.
- (void)mirrorEffectiveApplicationIntoAppGroup {
    @synchronized (_switchLock) {
        if (_isApplyingSwitch) {
            return;
        }
        [self mirrorEffectiveApplicationIntoAppGroupWithAppCode:[self appCode] baseUrl:[self baseUrl]];
    }
}

- (void)mirrorEffectiveApplicationIntoAppGroupWithAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl {
    NSString *appGroupsName = [[PWConfig config] appGroupsName];
    if (appGroupsName.length == 0) {
        return;
    }
    if (![self.class hasActiveApplicationRecord]) {
        return;
    }
    if (appCode.length == 0) {
        return;
    }

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:appGroupsName];
    [shared setObject:[self.class pairRecordWithAppCode:appCode baseUrl:baseUrl] forKey:KeyEffectiveApplication];
    [shared synchronize];
}

- (BOOL)switchToApplicationWithAppCode:(NSString *)appCode baseUrl:(NSString *)baseUrl {
    return [self switchToApplicationWithAppCode:appCode baseUrl:baseUrl previousPair:NULL];
}

- (BOOL)switchToApplicationWithAppCode:(NSString *)appCode
                               baseUrl:(NSString *)baseUrl
                          previousPair:(NSDictionary<NSString *, NSString *> **)previousPair {
    NSString *trimmed = [appCode isKindOfClass:[NSString class]]
        ? [appCode stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
        : nil;

    if (trimmed.length == 0) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:[PWPreferences class]
                           message:@"setAppCode(_:baseUrl:) rejected: application code must not be empty. Nothing was changed."];
        return NO;
    }

    if ([trimmed rangeOfString:@"."].location != NSNotFound) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:[PWPreferences class]
                           message:@"setAppCode(_:baseUrl:) rejected: application id format with '.' is deprecated. Please contact Pushwoosh support. Nothing was changed."];
        return NO;
    }

    /// `nil` = internal "resolve the default" (the public API routes an absent URL — nil, empty or
    /// whitespace-only — to `-setAppCode:` and never reaches here); an empty string arriving on this
    /// internal entry point is a malformed URL and rejects the whole call.
    NSString *normalized = nil;
    if (baseUrl != nil) {
        normalized = [self.class normalizeBaseUrl:baseUrl];
        if (normalized == nil) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:[PWPreferences class]
                               message:@"setAppCode(_:baseUrl:) rejected: base URL invalid, nothing was changed"];
            return NO;
        }
    }

    /// Before the lock: lets the pending `setTags` window drain under the code it was accumulated for.
    [self announceUpcomingApplicationChangeIfCodeMoves:trimmed];

    BOOL isNoOp = NO;
    BOOL appCodeChanged = NO;
    BOOL shouldResetInbox = NO;
    NSString *previousAppCode = nil;
    NSString *previousBaseUrl = nil;

    /// The no-op verdict is decided under the same lock as the apply, so a constant-pair call cannot
    /// return YES while another thread commits a different application underneath.
    @synchronized (_switchLock) {
        NSDictionary *record = [self.class readActiveApplicationRecord];
        NSString *recordedAppCode = record[kPWActiveApplicationAppCodeKey];
        NSString *recordedBaseUrl = record[kPWActiveApplicationBaseUrlKey];

        /// Full no-op when the state is already in effect. The endpoint half compares against the
        /// EFFECTIVE URL, so repeating the pair after a server rotation re-asserts it (ADR-11).
        NSString *effectiveBaseUrl = [self baseUrl];
        isNoOp = (record != nil
                  && [recordedAppCode isEqualToString:trimmed]
                  && ((normalized == nil && recordedBaseUrl == nil)
                      || (normalized != nil && [effectiveBaseUrl isEqualToString:normalized])));

        if (!isNoOp) {
            @synchronized (_lock) {
                previousAppCode = [_appCode copy];
            }
            previousBaseUrl = effectiveBaseUrl;

            _isApplyingSwitch = YES;

            [self writeActiveApplicationRecordWithAppCode:trimmed baseUrl:normalized];

            if (normalized != nil) {
                [self updateBaseUrl:normalized];
            } else {
                [self clearEffectiveBaseUrl];
            }

            appCodeChanged = ![trimmed isEqualToString:(recordedAppCode.length > 0 ? recordedAppCode : previousAppCode)];

            /// The internal apply, NOT the public setter — the setter's side effects (inbox reset, KVO,
            /// notification) would run under this lock. The transaction pays them below, outside it.
            [self applyAppCode:trimmed resetInbox:&shouldResetInbox];

            /// A host move forces no registration (same backend), but clears the dedup so the next
            /// ordinary `-updateRegistration` reaches the new host instead of waiting out the 24h window.
            if (!appCodeChanged) {
                self.lastRegTime = nil;
                self.lastRegisterUserDate = nil;
            }

            _isApplyingSwitch = NO;
            [self mirrorEffectiveApplicationIntoAppGroupWithAppCode:trimmed baseUrl:[self baseUrl]];
        }
    }

    if (isNoOp) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG
                         className:[PWPreferences class]
                           message:[NSString stringWithFormat:@"setAppCode(_:baseUrl:): %@ is already the selected application with the same endpoint, nothing to do.", trimmed]];
        return YES;
    }

    /// The apply's debts, paid outside every lock in the order the public setter pays them.
    if (shouldResetInbox) {
        [self resetInboxForApplicationChange];
    }

    [self announceAppCodeChange];

    if (previousPair != NULL) {
        *previousPair = @{ kPWActiveApplicationAppCodeKey: previousAppCode ?: @"",
                           kPWActiveApplicationBaseUrlKey: previousBaseUrl ?: @"" };
    }

    if ([[PWConfig config] appGroupsName].length == 0) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:[PWPreferences class]
                           message:@"setAppCode(_:baseUrl:): no App Group is configured (PW_APP_GROUPS_NAME). The Notification Service Extension cannot see the selected application, so messageDeliveryEvent will keep going to the Info.plist application. Add the same App Group to the app and the extension target."];
    }

    [PushwooshLog pushwooshLog:PW_LL_INFO
                     className:[PWPreferences class]
                       message:[NSString stringWithFormat:@"Switched active application: %@ -> %@, base URL: %@ -> %@",
                                previousAppCode.length > 0 ? previousAppCode : @"(none)", trimmed,
                                previousBaseUrl.length > 0 ? previousBaseUrl : @"(none)",
                                normalized.length > 0 ? normalized : @"(default)"]];

    /// Only the transaction can tell an application change from an endpoint move — by the time an
    /// observer looks, the record already holds the new pair — so the flag travels with the notification.
    [[NSNotificationCenter defaultCenter] postNotificationName:kPWActiveApplicationChangedNotification
                                                        object:nil
                                                      userInfo:@{ kPWActiveApplicationChangedAppCodeChangedKey: @(appCodeChanged) }];

    return YES;
}

- (NSString *)updateBaseUrl:(NSString *)rawUrl
        ifSelectedPairMatchesAppCode:(NSString *)pinnedAppCode
                             baseUrl:(NSString *)pinnedBaseUrl {
    @synchronized (_switchLock) {
        if (pinnedAppCode.length > 0) {
            NSString *currentAppCode = [self appCode] ?: @"";
            NSString *currentBaseUrl = [self baseUrl] ?: @"";
            BOOL stillCurrent = [pinnedAppCode isEqualToString:currentAppCode]
                && [(pinnedBaseUrl ?: currentBaseUrl) isEqualToString:currentBaseUrl];
            if (!stillCurrent) {
                return nil;
            }
        } else if ([PWPreferences hasActiveApplicationRecord]) {
            /// Every live send pins once a record exists, so an unpinned response predates the record —
            /// it must not move the endpoint of an application the integrator has since selected.
            return nil;
        }
        return [self updateBaseUrl:rawUrl];
    }
}

- (NSDictionary<NSString *, NSString *> *)activeApplicationSnapshot {
    @synchronized (_switchLock) {
        NSString *code = [self appCode] ?: @"";
        NSString *url = [self baseUrl] ?: @"";
        return @{ kPWActiveApplicationAppCodeKey: code, kPWActiveApplicationBaseUrlKey: url };
    }
}

- (void)loadActiveApplicationFromAppGroups:(NSString *)appGroupsName {
    if (appGroupsName.length == 0) {
        appGroupsName = [[PWConfig config] appGroupsName];
    }

    if (appGroupsName.length == 0) {
        static dispatch_once_t missingAppGroupWarningOnce;
        dispatch_once(&missingAppGroupWarningOnce, ^{
            [PushwooshLog pushwooshLog:PW_LL_WARN
                             className:[PWPreferences class]
                               message:@"No App Group is configured, so the application selected by the host app cannot be read here. Add the same PW_APP_GROUPS_NAME App Group to the app and the extension target."];
        });
        return;
    }

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:appGroupsName];

    /// Effective pair first, so the extension follows a legitimate server rotation of the endpoint;
    /// the integrator's record is the fallback for hosts that have not rotated anything yet.
    NSDictionary *record = [self.class validatedActiveApplicationRecord:[shared objectForKey:KeyEffectiveApplication]];
    if (record == nil) {
        record = [self.class validatedActiveApplicationRecord:[shared objectForKey:KeyActiveApplication]];
    }
    if (record == nil) {
        return;
    }

    NSString *recordAppCode = record[kPWActiveApplicationAppCodeKey];
    NSString *recordBaseUrl = record[kPWActiveApplicationBaseUrlKey];

    /// Read-only apply in one critical section: the extension must never become a writer, and a
    /// concurrent pin must never observe the new code next to the previous base URL.
    @synchronized (_switchLock) {
        @synchronized (_lock) {
            if (![recordAppCode isEqualToString:_appCode]) {
                _appCode = [recordAppCode copy];
            }
            _baseUrl = [recordBaseUrl copy];
        }
    }
}

#pragma mark - Keychain Persistent HWID

- (NSString *)getPersistentHWIDIfAvailable {
    id<PWKeychainPersistentHWIDProvider> provider =
        [PushwooshModuleRegistry handlerForIdentifier:PWModuleIdentifierKeychain];
    if (!provider || !provider.isPersistentHWIDEnabled) {
        return nil;
    }
    return [provider persistentHWID];
}

@end
