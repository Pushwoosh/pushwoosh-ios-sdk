//
//  PWPreferences.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import "PWPreferences.h"
#import "PWConfig.h"
#import "PWUtils.h"
#import "Pushwoosh+Internal.h"
#import "Constants.h"

#if TARGET_OS_IOS
#import "PWInbox+Internal.h"
#endif

static NSString *const KeyAppId = @"Pushwoosh_APPID";
static NSString *const KeyInfoPlistAppId = @"Pushwoosh_INFO_PLIST_APPID";
static NSString *const KeyAppName = @"Pushwoosh_APPNAME";
static NSString *const KeyPushToken = @"PWPushUserId";
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

@interface PWPreferences ()

@property (nonatomic, strong) NSObject *lock;
@property (nonatomic) NSUserDefaults *defaults;

@end

@implementation PWPreferences

@synthesize appCode = _appCode;

- (instancetype)init {
	self = [super init];
	if (self) {
		[[NSUserDefaults standardUserDefaults] synchronize];

		_lock = [NSObject new];
    
        
		//if needed reset application setting after update app code
        [self setAppCode:[PWPreferences readAppId]];

	}

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
#if TARGET_OS_IOS
    [PWInbox resetApplication];
#endif
    
    [self.class resetCache];
}

+ (void)resetCache {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyBaseUrl];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyLastRegTime];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyLastSendAttrDate];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyLastRegisterUserDate];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyPushwooshCategories];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

// Priority:
// 1. mainBundle[Pushwoosh_APPNAME]
// 2. standardUserDefaults[Pushwoosh_APPNAME]
// 3. mainBundle[CFBundleDisplayName]
// 4. mainBundle[CFBundleName]
// 5. @""
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

#pragma mark - AppCode

- (void)setAppCode:(NSString *)appCode {
    @synchronized(_lock) {
        _appCode = [appCode copy];
        
        if ([PWPreferences checkAppCodeforChanges:appCode]) {
            //need reset application setting after update app code
            [self resetApplicationSetting];
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:appCode forKey:KeyAppId];
    [[NSUserDefaults standardUserDefaults] synchronize];
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

// Priority:
// 1. mainBundle[Pushwoosh_APPID/Pushwoosh_APPID_Dev]
// 2.standardUserDefaults[Pushwoosh_APPID]
// 3. @""
+ (NSString *)readAppId {
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
        return infoPlistAppCode;
    } else {
        return @"";
    }
}

- (BOOL)hasAppCode {
    NSString *code = self.appCode;
    if (code && code.length > 0) {
        return YES;
    }
    
    return NO;
}

@end
