//
//  PWPreferences.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import <Foundation/Foundation.h>

@interface PWPreferences : NSObject

+ (instancetype)preferences;

@property (nonatomic) BOOL showForegroundNotifications;

@property (copy) NSString *appCode;

@property (copy) NSString *appName;

@property (copy) NSString *pushToken;

@property (copy) NSString *userId;

@property (copy) NSDate *lastRegTime;

@property (nonatomic) NSInteger lastStatusMask;

@property (copy) NSArray *categories;

@property (copy) NSString *baseUrl;

@property (nonatomic) BOOL isLoggerActive;

@property (copy) NSDate *lastRegisterUserDate;

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
