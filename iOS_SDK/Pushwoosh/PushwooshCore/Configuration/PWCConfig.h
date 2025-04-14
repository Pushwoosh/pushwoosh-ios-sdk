//
//  PWCConfig.h
//  PushwooshCore
//
//  Created by André Kis on 10.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <PushwooshCore/PWCNotificationAppSettings.h>
#import <PushwooshCore/PushwooshLog.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWCConfig : NSObject

+ (PWCConfig *)config NS_SWIFT_NAME(configInstance());

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
 key: Pushwoosh_LOG_LEVEL
 type: string
 value: Pushwoosh SDK logging level (NONE, ERROR, WARNING, INFO, DEBUG, VERBOSE)
 */
@property (nonatomic, assign, readonly) PUSHWOOSH_LOG_LEVEL logLevel;

@property (nonatomic, readonly) BOOL sendPushStatIfAlertsDisabled;

@property (nonatomic, readonly) BOOL sendPurchaseTrackingEnabled;

@property (nonatomic, assign, readonly) BOOL preHandleNotificationsWithUrl;

@property (nonatomic, readonly) BOOL lazyInitialization;

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

- (instancetype)initWithBundle:(NSBundle *)bundle;

@end

NS_ASSUME_NONNULL_END
