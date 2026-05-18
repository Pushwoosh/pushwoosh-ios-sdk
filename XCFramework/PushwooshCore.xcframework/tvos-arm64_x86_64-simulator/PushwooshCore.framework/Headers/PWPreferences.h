//
//  PWPreferences.h
//  PushwooshCore
//
//  Created by André Kis on 11.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

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

@property (copy) NSString *language;

@property (copy) NSDictionary *customTags;

@property (copy, nullable) NSString *advertisingId;

- (BOOL)hasAppCode;
- (nullable NSString *)defaultBaseUrl;

- (void)saveCurrentHWIDtoUserDefaults;

+ (BOOL)checkAppCodeforChanges:(NSString *)appCode;

@end

NS_ASSUME_NONNULL_END
