//
//  PWPreferences.h
//  PushwooshCore
//
//  Created by André Kis on 11.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Keys of the (application code, base URL) pair returned by `-activeApplicationSnapshot` and
/// `-switchToApplicationWithAppCode:baseUrl:previousPair:`.
FOUNDATION_EXPORT NSString * const kPWActiveApplicationAppCodeKey;
FOUNDATION_EXPORT NSString * const kPWActiveApplicationBaseUrlKey;

@interface PWPreferences : NSObject

+ (instancetype)preferences NS_SWIFT_NAME(preferencesInstance());

/// Returns YES if PWPreferences is currently being initialized.
/// Used to prevent recursive calls during singleton initialization.
+ (BOOL)isInitializing;

@property (nonatomic) BOOL showForegroundNotifications;

@property (copy) NSString *appCode;

@property (copy) NSString *appName;

@property (copy, nullable) NSString *pushToken;

@property (copy, nullable) NSString *voipPushToken;

@property (copy, nullable) NSString *pushTvToken;

@property (copy) NSString *userId;

@property (copy, nullable) NSDate *lastRegTime;

@property (nonatomic) NSInteger lastStatusMask;

@property (copy) NSArray *categories;

@property (copy, readonly, nullable) NSString *baseUrl;

/**
 * Persists a new base URL after normalization (trim, scheme check, force trailing `/`).
 * Single entry point for all base-URL writers (response.base_url, set_base_url system command,
 * setAppCode:-derived default, integrator-set custom URL).
 *
 * @param rawUrl raw URL string from any source; may be nil.
 * @return the normalized URL on accept, or nil if the input was empty / malformed / failed validation.
 *         On nil return, the previously persisted base URL is preserved.
 */
- (nullable NSString *)updateBaseUrl:(nullable NSString *)rawUrl;

/// Deprecated. Use `-updateBaseUrl:` so the value is normalized and de-duplicated.
- (void)setBaseUrl:(nullable NSString *)baseUrl __attribute__((deprecated("Use -updateBaseUrl: instead.")));

@property (nonatomic) BOOL isLoggerActive;

@property (copy) NSDate *lastRegisterUserDate;

@property (copy) NSString *apiToken;

@property (copy, readonly) NSString *hwid;

@property (copy, readonly) NSString *previosHWID;

@property (nonatomic, assign) unsigned int logLevel;

@property (nonatomic) BOOL registrationEverOccured;

@property (nonatomic) BOOL isServerCommunicationEnabled;

@property (nonatomic) BOOL isAutoDeviceTokenRegistrationEnabled;

@property (copy) NSString *language;

@property (copy) NSDictionary *customTags;

@property (copy, nullable) NSString *advertisingId;

@property (nonatomic) NSTimeInterval lastKnockTriggerTimestamp;

- (BOOL)hasAppCode;
- (nullable NSString *)defaultBaseUrl;

- (void)saveCurrentHWIDtoUserDefaults;

+ (BOOL)checkAppCodeforChanges:(NSString *)appCode;

#pragma mark - Active application (application code + base URL as one unit)

/// Atomically switches the active application: code and base URL move together or not at all.
/// Returns YES when applied; NO when an input was rejected (nothing is written).
- (BOOL)switchToApplicationWithAppCode:(NSString *)appCode baseUrl:(nullable NSString *)baseUrl;

/// As above, and reports the superseded pair captured inside the critical section — the unregister
/// MUST use this, not a pre-call read. `previousPair` may be NULL; untouched on NO and on a no-op.
- (BOOL)switchToApplicationWithAppCode:(NSString *)appCode
                               baseUrl:(nullable NSString *)baseUrl
                          previousPair:(NSDictionary<NSString *, NSString *> *_Nullable *_Nullable)previousPair;

/// Unregisters the device from a superseded pair (as reported via `previousPair`). Skipped with a
/// WARN when the previous host cannot be resolved — that traffic must not reach the current host.
- (void)unregisterFromVacatedApplication:(NSDictionary<NSString *, NSString *> *)vacatedApplication;

/// Applies a server-supplied endpoint only while the response's pinned pair is still current (verdict
/// and write under one lock); unpinned applies unconditionally. Returns the applied URL, or nil.
- (nullable NSString *)updateBaseUrl:(NSString *)rawUrl
        ifSelectedPairMatchesAppCode:(nullable NSString *)pinnedAppCode
                             baseUrl:(nullable NSString *)pinnedBaseUrl;

/// Atomic snapshot of the active pair (keys `appCode`/`baseUrl`, empty strings rather than nil).
/// MUST NOT be called from code already holding the preferences lock.
- (NSDictionary<NSString *, NSString *> *)activeApplicationSnapshot;

/// YES once the integrator has selected an application at runtime — gates every switch-specific
/// behaviour, so installs without a record behave exactly as before.
+ (BOOL)hasActiveApplicationRecord;

/// The recorded endpoint the integrator selected (nil = default / never switched); deliberately does
/// NOT follow a server rotation, unlike `baseUrl`. Diagnostics only.
- (nullable NSString *)selectedBaseUrl;

/// Extension-side reload of the pair the host app currently talks to. Strictly read-only — the host
/// app is the only writer of both App Group records. Falls back to `PWConfig.appGroupsName`.
- (void)loadActiveApplicationFromAppGroups:(nullable NSString *)appGroupsName;

@end

NS_ASSUME_NONNULL_END
