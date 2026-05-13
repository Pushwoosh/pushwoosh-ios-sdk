
#import <Foundation/Foundation.h>

#import <PushwooshCore/PushwooshLog.h>

typedef NS_ENUM(NSInteger, RichMediaStyleType) {
    PWRichMediaStyleTypeModal,
    PWRichMediaStyleTypeLegacy,
    PWRichMediaStyleTypeDefault
};

@interface PWConfig : NSObject

+ (PWConfig *)config;

/**
 key: Pushwoosh_APPID
 type: string
 value: Sets the Pushwoosh application ID for production build
 */
@property (nonatomic, copy, readonly) NSString *appId;

/**
 key: PW_API_TOKEN
 type: string
 value: Sets the Pushwoosh API auth token
 */

@property (nonatomic, copy, readonly) NSString *apiToken;

/**
 key: Pushwoosh_API_TOKEN
 type: string
 value: Sets the Pushwoosh API auth token
 */

@property (nonatomic, copy, readonly) NSString *pushwooshApiToken;

/**
 key: Pushwoosh_APPID_Dev
 type: string
 value: Sets the Pushwoosh application ID for development build
 */
@property (nonatomic, copy, readonly) NSString *appIdDev;

/**
 key: Pushwoosh_APPNAME
 type: string
 value: Sets the Pushwoosh application name
 */
@property (nonatomic, copy, readonly) NSString *appName;

/**
 key: PW_APP_GROUPS_NAME
 type: string
 value: Sets the App Groups name
 */
@property (nonatomic, copy, readonly) NSString *appGroupsName;

/**
 key: Pushwoosh_SHOW_ALERT
 type: boolean
 value: Shows notification foreground alert
 */
@property (nonatomic, assign, readonly) BOOL showAlert;

/**
 key: Pushwoosh_BASEURL
 type: string
 value: Overrides the Pushwoosh server base url
 */
@property (nonatomic, copy, readonly) NSString *requestUrl;

/**
 key: Pushwoosh_SDK_SELF_TEST_ENABLE
 type: boolean
 value: internal setting for testing pushes in simulator
 */
@property (nonatomic, assign, readonly) BOOL selfTestEnabled;

/**
 key: Pushwoosh_AUTO
 type: boolean
 value: deprecated setting for autointegration
 */
@property (nonatomic, assign, readonly) BOOL useRuntime;

/**
 key: Pushwoosh_ALLOW_SERVER_COMMUNICATION
 type: boolean
 value: Allows the SDK to send network requests to Pushwoosh servers (by default it is allowed)
 */
@property (nonatomic, assign, readonly) BOOL allowServerCommunication;

/**
 key: Pushwoosh_ALLOW_COLLECTING_DEVICE_DATA
 type: boolean
 value: Allows the SDK to collect and to send device data (OS version status, locale and model) to the server (by default it is allowed)
 */
@property (nonatomic, assign, readonly) BOOL allowCollectingDeviceData;

/**
 key: Pushwoosh_ALLOW_COLLECTING_DEVICE_OS_VERSION
 type: boolean
 value: Allows the SDK to collect and to send device OS version to the server (by default it is allowed)
 */
@property (nonatomic, assign, readonly) BOOL allowCollectingDeviceOsVersion;

/**
 key: Pushwoosh_ALLOW_COLLECTING_DEVICE_LOCALE
 type: boolean
 value: Allows the SDK to collect and to send device locale to the server (by default it is allowed)
 */
@property (nonatomic, assign, readonly) BOOL allowCollectingDeviceLocale;

/**
 key: Pushwoosh_ALLOW_COLLECTING_DEVICE_MODEL
 type: boolean
 value: Allows the SDK to collect and to send device model to the server (by default it is allowed)
 */
@property (nonatomic, assign, readonly) BOOL allowCollectingDeviceModel;

/**
 key: Pushwoosh_ALLOW_COLLECTING_EVENTS
 type: boolean
 value: Allows the SDK to send events (PW_ScreenOpen, PW_ApplicationOpen, PW_ApplicationMinimized) request ti the server (by default it is allwed)
 */
@property (nonatomic, assign, readonly) BOOL isCollectingLifecycleEventsAllowed;

/**
 key: Pushwoosh_IDLE_TIMEOUT_SECONDS
 type: integer
 value: Idle threshold in seconds for PW_UserIdle event. Minimum enforced to 30 seconds;
        values below 30 are clamped to 30 with a warning log.
        Default (key absent): 0 — idle detection disabled. Set the key explicitly to enable.
        Set to 0 or negative to disable idle detection entirely.
        Also forced to 0 when Pushwoosh_ALLOW_COLLECTING_EVENTS is NO.
 */
@property (nonatomic, assign, readonly) NSInteger idleTimeoutSeconds;

/**
 key: Pushwoosh_APPLICATION_EXIT_TIMEOUT_SECONDS
 type: integer
 value: Timeout (seconds) before PW_ApplicationExit fires after backgrounding.
        Range [10, 30]. Values outside the range are clamped with a warning log.
        Default (key absent or <= 0): 0 — feature disabled.
        Also forced to 0 when Pushwoosh_ALLOW_COLLECTING_EVENTS is NO.
        Note: event is lost if the OS terminates the process before the timer fires.
 */
@property (nonatomic, assign, readonly) NSInteger applicationExitTimeoutSeconds;

/**
 key: Pushwoosh_LOG_LEVEL
 type: string
 value: Pushwoosh SDK logging level (NONE, ERROR, WARNING, INFO, DEBUG, VERBOSE)
 */
@property (nonatomic, assign, readonly) PUSHWOOSH_LOG_LEVEL logLevel;

@property (nonatomic, readonly) BOOL sendPushStatIfAlertsDisabled;

@property (nonatomic, readonly) BOOL sendPurchaseTrackingEnabled;

@property (nonatomic, assign, readonly) BOOL preHandleNotificationsWithUrl;

/**
 key: Pushwoosh_DISABLE_URL_FALLBACK
 type: boolean
 value: If YES, disables fallback to Safari when continueUserActivity returns NO.
        Use this if your app handles Universal Links but swizzlers or other factors
        cause incorrect return values. Default is NO.
 */
@property (nonatomic, assign, readonly) BOOL disableUrlFallback;

@property (nonatomic, readonly) BOOL lazyInitialization;

@property (nonatomic, assign) RichMediaStyleType richMediaStyle;

/**
 key: Pushwoosh_PLUGIN_NOTIFICATION_HANDLER
 type: boolean
 value: Flag indicating whether the push notification handling is implemented by the plugin (YES) or by the SDK (NO). By default, this is set to NO.
 */
@property (nonatomic, readonly) BOOL isUsingPluginForPushHandling;


/**
key: Pushwoosh_AUTO_ACCEPT_DEEP_LINK_FOR_SILENT_PUSH
type: boolean
value: If YES, Deep Links received in silent pushes will be processed automatically (by default it is set to YES)
*/
@property (nonatomic, assign, readonly) BOOL acceptedDeepLinkForSilentPush;

/**
 key: Pushwoosh_PREFER_GRPC
 type: boolean
 value: Deprecated. gRPC transport is now used automatically when PushwooshGRPC module is linked.
 */
@property (nonatomic, assign, readonly) BOOL preferGRPC __attribute__((deprecated("gRPC is now used automatically when PushwooshGRPC module is linked")));

/**
 key: Pushwoosh_GRPC_HOST
 type: string
 value: Custom gRPC server host (default: grpc.pushwoosh.com)
 */
@property (nonatomic, copy, readonly) NSString *grpcHost;

/**
 key: Pushwoosh_GRPC_PORT
 type: integer
 value: Custom gRPC server port (default: 443)
 */
@property (nonatomic, assign, readonly) NSInteger grpcPort;

/**
 key: Pushwoosh_ALLOW_REVERSE_PROXY
 type: boolean
 value: If YES, allows routing SDK requests through a reverse proxy URL set via setReverseProxy:. Default is NO.
 */
@property (nonatomic, assign, readonly) BOOL allowReverseProxy;

/**
 key: Pushwoosh_TRACKING_URL
 type: string
 value: Custom tracking endpoint URL for advertising ID requests. Default is https://tracking.svc-nue.pushwoosh.com/api/v2/device-api/
 */
@property (nonatomic, copy, readonly, nullable) NSString *trackingUrl;

- (instancetype)initWithBundle:(NSBundle *)bundle;

@end
