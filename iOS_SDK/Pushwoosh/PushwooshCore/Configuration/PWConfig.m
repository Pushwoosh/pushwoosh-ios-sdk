
#import "PWConfig.h"

static NSString * const kPWRichMediaStyleModalKey = @"PWRichMediaStyleModal";
static NSString * const kPWRichMediaPresentationStyleKey = @"PWRichMediaPresentationStyle";

/// Flag to prevent recursive dispatch_once entry during +config initialization.
/// Set inside -initWithBundle: so that any pushwoosh_Log emitted from the initializer
/// (e.g. invalid appCode/log-level warnings) does not re-call [PWConfig config].
static BOOL _isInitializing = NO;

@interface PWConfig ()

@property (nonatomic, copy, readwrite) NSString *appId;
@property (nonatomic, copy, readwrite) NSString *apiToken;
@property (nonatomic, copy, readwrite) NSString *pushwooshApiToken;
@property (nonatomic, copy, readwrite) NSString *appIdDev;
@property (nonatomic, copy, readwrite) NSString *appName;
@property (nonatomic, copy, readwrite) NSString *appGroupsName;
@property (nonatomic, assign, readwrite) BOOL showAlert;
@property (nonatomic, copy, readwrite) NSString *requestUrl;
@property (nonatomic, assign, readwrite) BOOL useRuntime;
@property (nonatomic, assign, readwrite) BOOL allowServerCommunication;
@property (nonatomic, assign, readwrite) BOOL allowCollectingDeviceData;
@property (nonatomic, assign, readwrite) BOOL allowCollectingDeviceOsVersion;
@property (nonatomic, assign, readwrite) BOOL allowCollectingDeviceLocale;
@property (nonatomic, assign, readwrite) BOOL allowCollectingDeviceModel;
@property (nonatomic, assign, readwrite) BOOL isCollectingLifecycleEventsAllowed;
@property (nonatomic, assign, readwrite) NSInteger idleTimeoutSeconds;
@property (nonatomic, assign, readwrite) NSInteger applicationExitTimeoutSeconds;
@property (nonatomic, assign, readwrite) PUSHWOOSH_LOG_LEVEL logLevel;
@property (nonatomic, readwrite) BOOL sendPushStatIfAlertsDisabled;
@property (nonatomic, assign, readwrite) BOOL acceptedDeepLinkForSilentPush;
@property (nonatomic, readwrite) BOOL sendPurchaseTrackingEnabled;
@property (nonatomic, assign, readwrite) BOOL preHandleNotificationsWithUrl;
@property (nonatomic, assign, readwrite) BOOL disableUrlFallback;
@property (nonatomic, assign, readwrite) BOOL lazyInitialization;
@property (nonatomic, readwrite) BOOL isUsingPluginForPushHandling;

@property (nonatomic, assign, readwrite) BOOL allowReverseProxy;
@property (nonatomic, copy, readwrite) NSString *trackingUrl;

// gRPC configuration
@property (nonatomic, assign, readwrite) BOOL preferGRPC;
@property (nonatomic, copy, readwrite) NSString *grpcHost;
@property (nonatomic, assign, readwrite) NSInteger grpcPort;

@property (nonatomic) NSBundle *bundle;

/// When the SDK runs inside an app extension (NSE), this is the containing host app bundle, used as
/// a fallback so `Pushwoosh_*` keys set only in the main target are visible to the extension. nil in
/// the main app and whenever the host bundle can't be resolved.
@property (nonatomic) NSBundle *hostBundle;

@end

@implementation PWConfig

- (NSString *)trimmedStringForKey:(NSString *)key {
    id raw = [self infoValueForKey:key];
    if (![raw isKindOfClass:[NSString class]]) {
        return nil;
    }
    NSString *trimmed = [(NSString *)raw stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : nil;
}

/// Reads an Info.plist value from the extension's own bundle first, then falls back to the host app
/// bundle when running inside an app extension. The extension's own value always wins, so a key set
/// explicitly in the extension Info.plist overrides the host. A nil or blank (empty/whitespace)
/// string in the extension is treated as absent, so a placeholder like an unresolved `$(VAR)` does
/// not block inheritance from the host.
- (id)infoValueForKey:(NSString *)key {
    id value = [_bundle objectForInfoDictionaryKey:key];

    BOOL blank = (value == nil) ||
        ([value isKindOfClass:[NSString class]] &&
         [[(NSString *)value stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0);

    if (blank && _hostBundle != nil) {
        value = [_hostBundle objectForInfoDictionaryKey:key];
    }
    return value;
}

/// Resolves the containing host app bundle when `bundle` is an app extension, so the extension can
/// inherit `Pushwoosh_*` configuration (App ID, App Group name, etc.) set only in the main target.
/// Gated on the mandatory `NSExtension` Info.plist key, so the main app and unit-test bundles return
/// nil without touching `bundleURL`. Returns nil when no enclosing `.app` is found.
+ (NSBundle *)hostAppBundleForExtensionBundle:(NSBundle *)bundle {
    if ([bundle objectForInfoDictionaryKey:@"NSExtension"] == nil) {
        return nil;
    }

    NSURL *candidate = [[bundle bundleURL] URLByDeletingLastPathComponent];
    for (NSInteger depth = 0; depth < 5 && candidate != nil; depth++) {
        if ([[candidate pathExtension] isEqualToString:@"app"]) {
            return [NSBundle bundleWithURL:candidate];
        }
        NSURL *parent = [candidate URLByDeletingLastPathComponent];
        if (parent == nil || [parent isEqual:candidate]) {
            break;
        }
        candidate = parent;
    }
    return nil;
}

- (instancetype)initWithBundle:(NSBundle *)bundle {
    return [self initWithBundle:bundle hostBundle:[PWConfig hostAppBundleForExtensionBundle:bundle]];
}

- (instancetype)initWithBundle:(NSBundle *)bundle hostBundle:(NSBundle *)hostBundle {
	self = [super init];
	if (self) {
        _isInitializing = YES;

        _bundle = bundle;
        _hostBundle = hostBundle;

		self.appId = [self trimmedStringForKey:@"Pushwoosh_APPID"];
        if (self.appId != nil && [self.appId rangeOfString:@"."].location != NSNotFound) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:[PWConfig class]
                               message:@"Pushwoosh_APPID ignored — Application id format with '.' is deprecated. Please contact Pushwoosh support."];
            self.appId = nil;
        }

        self.apiToken = [self trimmedStringForKey:@"PW_API_TOKEN"];

        self.pushwooshApiToken = [self trimmedStringForKey:@"Pushwoosh_API_TOKEN"];

		self.appIdDev = [self trimmedStringForKey:@"Pushwoosh_APPID_Dev"];
        if (self.appIdDev != nil && [self.appIdDev rangeOfString:@"."].location != NSNotFound) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:[PWConfig class]
                               message:@"Pushwoosh_APPID_Dev ignored — Application id format with '.' is deprecated. Please contact Pushwoosh support."];
            self.appIdDev = nil;
        }

		self.appName = [self trimmedStringForKey:@"Pushwoosh_APPNAME"];

        self.appGroupsName = [self trimmedStringForKey:@"PW_APP_GROUPS_NAME"];
        
        self.isUsingPluginForPushHandling = [self getBoolean:@"Pushwoosh_PLUGIN_NOTIFICATION_HANDLER" default:NO];

		self.showAlert = [self getBoolean:@"Pushwoosh_SHOW_ALERT" default:YES];

        self.sendPushStatIfAlertsDisabled = [self getBoolean:@"Pushwoosh_SHOULD_SEND_PUSH_STATS_IF_ALERT_DISABLED" default:NO];

        [self styleRichMediaTypeFromString:[self trimmedStringForKey:@"Pushwoosh_RICH_MEDIA_STYLE"]];

		self.requestUrl = [self trimmedStringForKey:@"Pushwoosh_BASEURL"];

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
        self.disableUrlFallback = [self getBoolean:@"Pushwoosh_DISABLE_URL_FALLBACK" default:NO];

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

        self.idleTimeoutSeconds = [self resolveIdleTimeoutSeconds];
        self.applicationExitTimeoutSeconds = [self resolveApplicationExitTimeoutSeconds];

		NSString *logLevelString = [self trimmedStringForKey:@"Pushwoosh_LOG_LEVEL"];

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

        self.allowReverseProxy = [self getBoolean:@"Pushwoosh_ALLOW_REVERSE_PROXY" default:NO];

        self.trackingUrl = [self trimmedStringForKey:@"Pushwoosh_TRACKING_URL"];

        // gRPC configuration
        self.preferGRPC = [self getBoolean:@"Pushwoosh_PREFER_GRPC" default:NO];
        self.grpcHost = [self trimmedStringForKey:@"Pushwoosh_GRPC_HOST"] ?: @"grpc.pushwoosh.com";

        NSNumber *grpcPortNum = [self infoValueForKey:@"Pushwoosh_GRPC_PORT"];
        self.grpcPort = grpcPortNum ? [grpcPortNum integerValue] : 443;

        _isInitializing = NO;
	}

	return self;
}

+ (BOOL)isInitializing {
    return _isInitializing;
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

- (NSInteger)resolveIdleTimeoutSeconds {
    static NSInteger const kMinIdleTimeoutSeconds = 30;

    if (!self.isCollectingLifecycleEventsAllowed) {
        return 0;
    }

    NSNumber *raw = [self infoValueForKey:@"Pushwoosh_IDLE_TIMEOUT_SECONDS"];
    if (!raw) {
        return 0;
    }

    NSInteger value = [raw integerValue];
    if (value <= 0) {
        return 0;
    }
    if (value < kMinIdleTimeoutSeconds) {
        NSString *message = [NSString stringWithFormat:@"Idle timeout %lds is below minimum (%lds). Using %lds.",
                             (long)value, (long)kMinIdleTimeoutSeconds, (long)kMinIdleTimeoutSeconds];
        dispatch_async(dispatch_get_main_queue(), ^{
            [PushwooshLog pushwooshLog:PW_LL_WARN
                             className:[PWConfig class]
                               message:message];
        });
        return kMinIdleTimeoutSeconds;
    }
    return value;
}

- (NSInteger)resolveApplicationExitTimeoutSeconds {
    static NSInteger const kMinApplicationExitTimeoutSeconds = 10;
    static NSInteger const kMaxApplicationExitTimeoutSeconds = 30;

    if (!self.isCollectingLifecycleEventsAllowed) {
        return 0;
    }

    NSNumber *raw = [self infoValueForKey:@"Pushwoosh_APPLICATION_EXIT_TIMEOUT_SECONDS"];
    if (!raw) {
        return 0;
    }

    NSInteger value = [raw integerValue];
    if (value <= 0) {
        return 0;
    }
    if (value < kMinApplicationExitTimeoutSeconds) {
        NSString *message = [NSString stringWithFormat:@"Application exit timeout %lds is below minimum (%lds). Using %lds.",
                             (long)value, (long)kMinApplicationExitTimeoutSeconds, (long)kMinApplicationExitTimeoutSeconds];
        dispatch_async(dispatch_get_main_queue(), ^{
            [PushwooshLog pushwooshLog:PW_LL_WARN
                             className:[PWConfig class]
                               message:message];
        });
        return kMinApplicationExitTimeoutSeconds;
    }
    if (value > kMaxApplicationExitTimeoutSeconds) {
        NSString *message = [NSString stringWithFormat:@"Application exit timeout %lds is above maximum (%lds). Using %lds.",
                             (long)value, (long)kMaxApplicationExitTimeoutSeconds, (long)kMaxApplicationExitTimeoutSeconds];
        dispatch_async(dispatch_get_main_queue(), ^{
            [PushwooshLog pushwooshLog:PW_LL_WARN
                             className:[PWConfig class]
                               message:message];
        });
        return kMaxApplicationExitTimeoutSeconds;
    }
    return value;
}

- (BOOL)getBoolean:(NSString *)key default:(BOOL)defaultValue {
	NSNumber *booleanObj = [self infoValueForKey:key];
	if (booleanObj && ([booleanObj isKindOfClass:[NSNumber class]] || [booleanObj isKindOfClass:[NSString class]])) {
		return [booleanObj boolValue];
	}

	return defaultValue;
}

@end
