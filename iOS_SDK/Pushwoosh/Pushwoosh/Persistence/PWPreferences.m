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
#import "PWLog+Internal.h"

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
@synthesize appName = _appName;
@synthesize pushToken = _pushToken;
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

- (instancetype)init {
	self = [super init];
	if (self) {
		[[NSUserDefaults standardUserDefaults] synchronize];

		_lock = [NSObject new];
		
		NSString *previosHWID = [[NSUserDefaults standardUserDefaults] objectForKey:KeyDeviceId];
        _hwid = [PWUtils uniqueGlobalDeviceIdentifier];
        
        if (![PWUtils isValidHwid:previosHWID] ) {
            [self saveCurrentHWIDtoUserDefaults];
        } else if (![_hwid isEqualToString:previosHWID]) { //check hwid changing
            _previosHWID = previosHWID;
        }
        
		//if needed reset application setting after update app code
        [self setAppCode:[PWPreferences readAppId]];
		_appName = [PWPreferences readAppName];
		_pushToken = [[NSUserDefaults standardUserDefaults] objectForKey:KeyPushToken];
		
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
        _baseUrl = [self readBaseUrl];
        
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
    _baseUrl = [self readBaseUrl];
    _lastRegTime = nil;
    _lastRegisterUserDate = nil;
    _categories = nil;
}

+ (void)resetCache {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyBaseUrl];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyLastRegTime];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyLastSendAttrDate];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyLastRegisterUserDate];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:KeyPushwooshCategories];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)language {
    @synchronized(_lock) {
        return _language;
    }
}

- (void)setLanguage:(NSString *)language {
    if (!language || language.length != 2 ) { // this is not ISO 639-1 code
        language = [PWUtils preferredLanguage];
    }
    
    @synchronized(_lock) {
        _language = [language copy];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:language forKey:KeyLanguage];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    self.lastRegTime = NSDate.distantPast; //reset last /registerDevice request time
    
    [[Pushwoosh sharedInstance].pushNotificationManager updateRegistration]; //send /registerDevice request
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
		PWLogError(@"userId cannot be nil");
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
		PWLogError(@"Unable to save categories: %@", categories);
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
		return _baseUrl;
	}
}

- (void)setBaseUrl:(NSString *)baseUrl {
	@synchronized(_lock) {
		_baseUrl = [baseUrl copy];
	}

	[[NSUserDefaults standardUserDefaults] setObject:baseUrl forKey:KeyBaseUrl];
	[[NSUserDefaults standardUserDefaults] synchronize];
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

- (NSString *)readBaseUrl {
	NSString *serviceAddressUrl = [[NSUserDefaults standardUserDefaults] objectForKey:KeyBaseUrl];

	if (!serviceAddressUrl) {
		serviceAddressUrl = [self defaultBaseUrl];
	}

	return serviceAddressUrl;
}

- (NSString *)defaultBaseUrl {
	NSString *serviceAddressUrl = [PWConfig config].requestUrl;

	if (!serviceAddressUrl) {
        NSString *appCode = _appCode;
        if (!appCode) {
            appCode = [self.class readAppId];
        }
        if (appCode.length == 0 || [appCode rangeOfString:@"."].location != NSNotFound) {
            serviceAddressUrl = kBaseDefaultURLOld;
        } else {
            serviceAddressUrl = [NSString stringWithFormat:kBaseDefaultURLFormat, appCode];
        }
	}

	return serviceAddressUrl;
}

+ (LogLevel)readLogLevel {
	NSNumber *logLevelObject = [[NSUserDefaults standardUserDefaults] objectForKey:KeyLogLevel];
	if (![logLevelObject isKindOfClass: [NSNumber class]]) {
		logLevelObject = @([PWConfig config].logLevel);
	}
	
	return (LogLevel)logLevelObject.integerValue;
}

- (void)setRegistrationEverOccured:(BOOL)registrationEverOccured {
    _registrationEverOccured = registrationEverOccured;
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:KeyRegistrationEverOccured];
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

#pragma mark -

// property list objects: NSData, NSString, NSNumber, NSDate, NSArray, or NSDictionary. For NSArray and NSDictionary objects, their contents must be property list objects.
+ (BOOL)verifyObject:(id)object {
	if (!object) {
		// nil is OK
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

@end
