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

@property (copy) NSString *baseUrl;

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

- (BOOL)hasAppCode;
- (NSString *)defaultBaseUrl;

- (void)saveCurrentHWIDtoUserDefaults;

+ (BOOL)checkAppCodeforChanges:(NSString *)appCode;

@end

NS_ASSUME_NONNULL_END
