//
//  PWSettings.h
//  PushwooshCore
//
//  Created by André Kis on 11.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWSettings : NSObject

+ (instancetype)settings NS_SWIFT_NAME(settingsInstance());

@property (nonatomic) BOOL showForegroundNotifications;

@property (copy) NSString *appCode;

@property (copy) NSString *appName;

@property (copy, readonly) NSString *pushToken;

@property (copy) NSString *userId;

@property (copy, readonly) NSDate *lastRegTime;

@property (nonatomic) NSInteger lastStatusMask;

@property (copy) NSArray *categories;

@property (copy) NSString *baseUrl;

@property (nonatomic) BOOL isLoggerActive;

@property (copy, readonly) NSDate *lastRegisterUserDate;

@property (copy, readonly) NSString *hwid;

@property (copy, readonly) NSString *previosHWID; //not nil if hwid has been changed

@property (nonatomic, assign) unsigned int logLevel;

@property (nonatomic) BOOL registrationEverOccured;

@property (nonatomic) BOOL isServerCommunicationEnabled;

@property (copy) NSString *language;

@property (copy) NSDictionary *customTags;

- (BOOL)hasAppCode;
- (NSString *)defaultBaseUrl;

- (void)saveCurrentHWIDtoUserDefaults; //call after successfull migration

+ (BOOL)checkAppCodeforChanges:(NSString *)appCode;

@end

NS_ASSUME_NONNULL_END
