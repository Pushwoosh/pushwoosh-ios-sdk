
#import "PWConfig.h"

static NSString * const kPWRichMediaStyleModalKey = @"PWRichMediaStyleModal";
static NSString * const kPWRichMediaPresentationStyleKey = @"PWRichMediaPresentationStyle";

@interface PWConfig ()

@property (nonatomic, copy, readwrite) NSString *appId;
@property (nonatomic, copy, readwrite) NSString *apiToken;
@property (nonatomic, copy, readwrite) NSString *pushwooshApiToken;
@property (nonatomic, copy, readwrite) NSString *appIdDev;
@property (nonatomic, copy, readwrite) NSString *appName;
@property (nonatomic, copy, readwrite) NSString *appGroupsName;
@property (nonatomic, assign, readwrite) BOOL showAlert;
@property (nonatomic, copy, readwrite) NSString *requestUrl;
@property (nonatomic, assign, readwrite) BOOL selfTestEnabled;
@property (nonatomic, assign, readwrite) BOOL useRuntime;
@property (nonatomic, assign, readwrite) BOOL allowServerCommunication;
@property (nonatomic, assign, readwrite) BOOL allowCollectingDeviceData;
@property (nonatomic, assign, readwrite) BOOL allowCollectingDeviceOsVersion;
@property (nonatomic, assign, readwrite) BOOL allowCollectingDeviceLocale;
@property (nonatomic, assign, readwrite) BOOL allowCollectingDeviceModel;
@property (nonatomic, assign, readwrite) BOOL isCollectingLifecycleEventsAllowed;
@property (nonatomic, assign, readwrite) PUSHWOOSH_LOG_LEVEL logLevel;
@property (nonatomic, readwrite) BOOL sendPushStatIfAlertsDisabled;
@property (nonatomic, assign, readwrite) BOOL acceptedDeepLinkForSilentPush;
@property (nonatomic, readwrite) BOOL sendPurchaseTrackingEnabled;
@property (nonatomic, assign, readwrite) BOOL preHandleNotificationsWithUrl;
@property (nonatomic, assign, readwrite) BOOL lazyInitialization;
@property (nonatomic, readwrite) BOOL isUsingPluginForPushHandling;

// gRPC configuration
@property (nonatomic, assign, readwrite) BOOL preferGRPC;
@property (nonatomic, copy, readwrite) NSString *grpcHost;
@property (nonatomic, assign, readwrite) NSInteger grpcPort;

@property (nonatomic) NSBundle *bundle;

@end

@implementation PWConfig

- (instancetype)initWithBundle:(NSBundle *)bundle {
	self = [super init];
	if (self) {
        _bundle = bundle;

		self.appId = [bundle objectForInfoDictionaryKey:@"Pushwoosh_APPID"];

        self.apiToken = [bundle objectForInfoDictionaryKey:@"PW_API_TOKEN"];
        
        self.pushwooshApiToken = [bundle objectForInfoDictionaryKey:@"Pushwoosh_API_TOKEN"];

		self.appIdDev = [bundle objectForInfoDictionaryKey:@"Pushwoosh_APPID_Dev"];

		self.appName = [bundle objectForInfoDictionaryKey:@"Pushwoosh_APPNAME"];
        
        self.appGroupsName = [bundle objectForInfoDictionaryKey:@"PW_APP_GROUPS_NAME"];
        
        self.isUsingPluginForPushHandling = [self getBoolean:@"Pushwoosh_PLUGIN_NOTIFICATION_HANDLER" default:NO];

		self.showAlert = [self getBoolean:@"Pushwoosh_SHOW_ALERT" default:YES];

        self.sendPushStatIfAlertsDisabled = [self getBoolean:@"Pushwoosh_SHOULD_SEND_PUSH_STATS_IF_ALERT_DISABLED" default:NO];

        [self styleRichMediaTypeFromString:[bundle objectForInfoDictionaryKey:@"Pushwoosh_RICH_MEDIA_STYLE"]];

		self.requestUrl = [bundle objectForInfoDictionaryKey:@"Pushwoosh_BASEURL"];

		self.selfTestEnabled = [self getBoolean:@"Pushwoosh_SDK_SELF_TEST_ENABLE" default:NO];

		self.useRuntime = [self getBoolean:@"Pushwoosh_AUTO" default:NO];
        
        self.sendPurchaseTrackingEnabled = [self getBoolean:@"Pushwoosh_PURCHASE_TRACKING_ENABLED" default:NO];
        
        self.acceptedDeepLinkForSilentPush = [self getBoolean:@"Pushwoosh_AUTO_ACCEPT_DEEP_LINK_FOR_SILENT_PUSH" default:YES];
        // supporting backwards compatibility with previous flag name
        if (self.acceptedDeepLinkForSilentPush == YES) {
            self.acceptedDeepLinkForSilentPush = [self getBoolean:@"PWAutoAcceptDeepLinkForSilentPush" default:YES];
        }
        
        // this key is used to allow server communication (by default it is allowed)
        self.allowServerCommunication = [self getBoolean:@"Pushwoosh_ALLOW_SERVER_COMMUNICATION" default: YES];
        self.preHandleNotificationsWithUrl = [self getBoolean:@"Pushwoosh_PREHANDLE_URL_NOTIFICATIONS" default:YES];

        // this key is used to allow collecting and sending device data (by default it is allowed)
        self.allowCollectingDeviceData = [self getBoolean:@"Pushwoosh_ALLOW_COLLECTING_DEVICE_DATA" default: YES];
        
        if (self.allowCollectingDeviceData == NO) {
            self.allowCollectingDeviceOsVersion = NO;
            self.allowCollectingDeviceLocale = NO;
            self.allowCollectingDeviceModel = NO;
            self.isCollectingLifecycleEventsAllowed = NO;
        } else {
            // this key is used to allow collecting and sending device os version (by default it is allowed)
            self.allowCollectingDeviceOsVersion = [self getBoolean:@"Pushwoosh_ALLOW_COLLECTING_DEVICE_OS_VERSION" default: YES];
            
            // this key is used to allow collecting and sending device locale (by default it is allowed)
            self.allowCollectingDeviceLocale = [self getBoolean:@"Pushwoosh_ALLOW_COLLECTING_DEVICE_LOCALE" default: YES];
            
            // this key is used to allow collecting and sending device model (by default it is allowed)
            self.allowCollectingDeviceModel = [self getBoolean:@"Pushwoosh_ALLOW_COLLECTING_DEVICE_MODEL" default: YES];
            
            // this key is used to allow sending events (by default it is allowed)
            self.isCollectingLifecycleEventsAllowed = [self getBoolean:@"Pushwoosh_ALLOW_COLLECTING_EVENTS" default: YES];
        }
        
		NSString *logLevelString = [bundle objectForInfoDictionaryKey:@"Pushwoosh_LOG_LEVEL"];

		if (!logLevelString) {
			// default log level
			logLevelString = @"INFO";
		}

		NSDictionary *logLevelMap = @{ @"NONE" : @(PW_LL_NONE),
									   @"ERROR" : @(PW_LL_ERROR),
									   @"WARNING" : @(PW_LL_WARN),
									   @"INFO" : @(PW_LL_INFO),
									   @"DEBUG" : @(PW_LL_DEBUG),
									   @"VERBOSE" : @(PW_LL_VERBOSE) };

		NSNumber *logLevelObject = logLevelMap[logLevelString];
		if (!logLevelObject) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"[PW] [E] Error! Invalid log level. Setting default (DEBUG)"];
			logLevelObject = @(PW_LL_INFO);
		}

		self.logLevel = (PUSHWOOSH_LOG_LEVEL)logLevelObject.integerValue;
        
        self.lazyInitialization = [self getBoolean:@"Pushwoosh_LAZY_INITIALIZATION" default:NO];

        // gRPC configuration
        self.preferGRPC = [self getBoolean:@"Pushwoosh_PREFER_GRPC" default:NO];
        self.grpcHost = [bundle objectForInfoDictionaryKey:@"Pushwoosh_GRPC_HOST"] ?: @"grpc.pushwoosh.com";

        NSNumber *grpcPortNum = [bundle objectForInfoDictionaryKey:@"Pushwoosh_GRPC_PORT"];
        self.grpcPort = grpcPortNum ? [grpcPortNum integerValue] : 443;
	}

	return self;
}

- (void)styleRichMediaTypeFromString:(NSString *)style {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:kPWRichMediaPresentationStyleKey] != nil) {
        NSInteger savedStyle = [[NSUserDefaults standardUserDefaults] integerForKey:kPWRichMediaPresentationStyleKey];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPWRichMediaPresentationStyleKey];
        switch (savedStyle) {
            case 0:
                self.richMediaStyle = PWRichMediaStyleTypeModal;
                break;
            case 1:
                self.richMediaStyle = PWRichMediaStyleTypeLegacy;
                break;
            case 2:
            default:
                self.richMediaStyle = PWRichMediaStyleTypeDefault;
                break;
        }
        return;
    }

    if ([[NSUserDefaults standardUserDefaults] objectForKey:kPWRichMediaStyleModalKey] != nil) {
        _richMediaStyle = [[NSUserDefaults standardUserDefaults] boolForKey:kPWRichMediaStyleModalKey]
            ? PWRichMediaStyleTypeModal
            : PWRichMediaStyleTypeDefault;
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPWRichMediaStyleModalKey];
        return;
    }

    if ([style isEqualToString:@"MODAL_RICH_MEDIA"]) {
        self.richMediaStyle = PWRichMediaStyleTypeModal;
    } else if ([style isEqualToString:@"LEGACY_RICH_MEDIA"]) {
        self.richMediaStyle = PWRichMediaStyleTypeLegacy;
    } else {
        self.richMediaStyle = PWRichMediaStyleTypeDefault;
    }
}

+ (PWConfig *)config {
	static PWConfig *instance = nil;
	static dispatch_once_t pred;
    
    NSBundle *bundle = [NSBundle mainBundle];

	dispatch_once(&pred, ^{
        instance = [[PWConfig alloc] initWithBundle:bundle];
	});

	return instance;
}

- (BOOL)getBoolean:(NSString *)key default:(BOOL)defaultValue {
	NSNumber *booleanObj = [_bundle objectForInfoDictionaryKey:key];
	if (booleanObj && ([booleanObj isKindOfClass:[NSNumber class]] || [booleanObj isKindOfClass:[NSString class]])) {
		return [booleanObj boolValue];
	}

	return defaultValue;
}

@end
