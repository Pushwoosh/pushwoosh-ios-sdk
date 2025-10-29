//
//  PWPushNotificationsManager.m
//  PushNotificationManager
//
//  Created by Kaizer on 06/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWPushNotificationsManager.common.h"
#import "PWUtils.h"
#import "PWPreferences.h"
#import "PWRequestManager.h"
#import "PWNetworkModule.h"
#import "PWRegisterDeviceRequest.h"
#import "PWUnregisterDeviceRequest.h"
#import <PushwooshCore/PWManagerBridge.h>
#import "PWRegisterTestDeviceRequest.h"
#import "PWPlatformModule.h"
#import "PWNotificationManagerCompat.h"
#import "PWMessage+Internal.h"

#import "PWPushNotificationsManager+Internal.h"
#import "PWMessageDeliveryRequest.h"

#import <PushwooshCore/PWManagerBridge.h>
#import "PWDataManager.h"
#import "PWRichPushManager.h"
#import "PWInAppMessagesManager.h"


const NSTimeInterval kRegistrationUpdateInterval = 24 * 60 * 60;

typedef NS_ENUM(NSInteger, PWPlatform) {
    iOS = 1,
    SMS = 18,
    Whatsapp = 21
};


@interface PWPushNotificationsManagerCommon ()

@property (nonatomic, strong) NSDictionary *lastPushMessage;

// @Inject
@property (nonatomic, strong) PWRequestManager *requestManager;

// @Inject
@property (nonatomic, strong) PWNotificationManagerCompat *notificationManagerCompat;

@property (nonatomic) PWConfig *config;

@property (nonatomic) PushwooshRegistrationHandler registrationHandler;

@property (nonatomic) PWRegisterDeviceRequest *request;

@property (nonatomic) NSString *trackingAppCode;
@property (nonatomic) NSString *pendingPushToken;

@end

@implementation PWPushNotificationsManagerCommon

- (instancetype)initWithConfig:(PWConfig *)config {
    if (self = [self init]) {
        _config = config;
    }
    return self;
}

- (instancetype)init {
    if (self = [super init]) {
        [[PWNetworkModule module] inject:self];
        [[PWPlatformModule module] inject:self];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notificationStatusSyncCompleted:) name:kNotificationAuthorizationStatusUpdated object:nil];

        [[PWPreferences preferences] addObserver:self forKeyPath:@"appCode" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"appCode"]) {
        NSString *appCode = [PWPreferences preferences].appCode;

        if (appCode && ![appCode isEqualToString:@""] && ![[PWPreferences preferences].appCode isEqualToString:_trackingAppCode]) {
            _trackingAppCode = [PWPreferences preferences].appCode;

            dispatch_async(dispatch_get_main_queue(), ^{
                [self updateRegistration];

                if (self.pendingPushToken) {
                    [self sendDevTokenToServer:self.pendingPushToken];
                    self.pendingPushToken = nil;
                }
            });
        }
    }
}

- (void)dealloc {
    [[PWPreferences preferences] removeObserver:self forKeyPath:@"appCode"];
}

- (BOOL)isAppInBackground {
    return NO;
}

// if first registerDevice fails need to resend request again (not more than 1 time per 5 min)
- (void)updateRegistration {
    [[[PWPlatformModule module] notificationManagerCompat] getRemoteNotificationStatusWithCompletion:^(NSDictionary* status) {
        if (![@"1" isEqualToString:status[@"enabled"]])
            return;
        
        NSString * pushToken = [PWPreferences preferences].pushToken;
        
        if(pushToken) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self sendDevTokenToServer:pushToken triggerCallbacks:NO];
            });
        }
    }];
}

- (void)registerForPushNotificationsWithCompletion:(PushwooshRegistrationHandler)registrationHandler {
    if ([PWServerCommunicationManager sharedInstance].isServerCommunicationAllowed) {
        _registrationHandler = registrationHandler;
        [self internalRegisterForPushNotifications];
    } else {
        if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(onDidFailToRegisterForRemoteNotificationsWithError:)]) {
            NSError *error = [PWUtils pushwooshErrorWithCode:PWErrorCommunicationDisabled description:@"Communication with Pushwoosh is disabled"];
            NSMethodSignature *signature = [[PWManagerBridge shared].delegate methodSignatureForSelector:@selector(onDidFailToRegisterForRemoteNotificationsWithError:)];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setSelector:@selector(onDidFailToRegisterForRemoteNotificationsWithError:)];
            [invocation setTarget:[PWManagerBridge shared].delegate];
            [invocation setArgument:&error atIndex:2];
            [invocation invoke];
        }
        
        if (registrationHandler) {
            registrationHandler(nil, [PWUtils pushwooshErrorWithCode:PWErrorCommunicationDisabled description:@"Communication with Pushwoosh is disabled"]);
        }
    }
}

- (void)unregisterForPushNotificationsWithCompletion:(void (^)(NSError *))completion  {
    //we do not call [[UIApplication sharedApplication] unregisterForRemoteNotifications]; due to apple recommendations:
    //https://developer.apple.com/documentation/uikit/uiapplication/1623093-unregisterforremotenotifications?preferredLanguage=occ
    
    [self unregisterDeviceWithCompletion:completion];
}

+ (NSMutableDictionary *)getRemoteNotificationStatus {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    __block NSDictionary *result = @{};
    [[[PWPlatformModule module] notificationManagerCompat] getRemoteNotificationStatusWithCompletion:^(NSDictionary* status) {
        result = status;
        dispatch_semaphore_signal(semaphore);
    }];
    
    if (dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 2*(NSEC_PER_SEC)))) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"Failed to get notification setttings"];
    }
    
    return [result mutableCopy];
}

+ (void)clearNotificationCenter {
    [[[PWPlatformModule module] notificationManagerCompat] clearLocalNotifications];
}

- (void)sendDevTokenToServer:(NSString *)deviceID {
    [self sendDevTokenToServer:deviceID triggerCallbacks:YES];
}

- (void)sendTokenToDelegate:(NSString *)deviceID triggerCallbacks:(BOOL)triggerCallbacks{
    NSString *token = [[PWManagerBridge shared] getPushToken];
    
    if (token) {
        if (triggerCallbacks) {
            if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(onDidRegisterForRemoteNotificationsWithDeviceToken:)]) {
                [[PWManagerBridge shared].delegate performSelectorOnMainThread:@selector(onDidRegisterForRemoteNotificationsWithDeviceToken:) withObject:token waitUntilDone:NO];
            }
            
            if (_registrationHandler) {
                _registrationHandler(token, nil);
            }
        }
    }
}

- (void)notificationStatusSyncCompleted:(NSNotification *)notification {
    NSInteger actualStatusMask = [PWUtils getStatusesMask];
    [PWPreferences preferences].lastStatusMask = actualStatusMask;
}

- (void)sendDevTokenToServer:(NSString *)deviceID triggerCallbacks:(BOOL)triggerCallbacks {
    NSString *appCode = [PWPreferences preferences].appCode;
    if (!appCode || [appCode isEqualToString:@""]) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"appCode not set, delaying push token registration"];
        self.pendingPushToken = deviceID;
        return;
    }

    //only 1 request per kRegistrationUpdateInterval!
    NSDate *lastReg = [PWPreferences preferences].lastRegTime;
    NSInteger lastStatusMask = [PWPreferences preferences].lastStatusMask;

    if (lastReg) {
        NSTimeInterval secondsBetween = [[NSDate date] timeIntervalSinceDate:lastReg];

        if ([[PWPreferences preferences].pushToken isEqualToString:deviceID] &&
            secondsBetween < kRegistrationUpdateInterval &&
            lastStatusMask == [PWUtils getStatusesMask]) {

            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Registered for push notifications: %@", deviceID]];

            [self sendTokenToDelegate:deviceID triggerCallbacks:triggerCallbacks];

            return;
        }
    }

    [PWPreferences preferences].lastStatusMask = [PWUtils getStatusesMask];
    [PWPreferences preferences].lastRegTime = [NSDate date];

    [_requestManager sendRequest:[self requestParameters:deviceID platform:iOS] completion:^(NSError *error) {
        
        [[PWPreferences preferences] setCustomTags:nil];
        
        if (error == nil) {
            [PushwooshLog pushwooshLog:PW_LL_INFO
                             className:self
                               message:[NSString stringWithFormat:
                                        @"\nRegistered for push notifications\n"
                                        "Device ID: %@\n"
                                        "HWID: %@\n",
                                        deviceID, [PWPreferences preferences].hwid]];
            //registered on server, save last registration time to prevent multiple register request
            [PWPreferences preferences].lastRegTime = [NSDate date];
            
            [self sendTokenToDelegate:deviceID triggerCallbacks:triggerCallbacks];
        } else {
            //reset time
            [PWPreferences preferences].lastRegTime = NSDate.distantPast;
            
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:@"Registered for push notifications failed"];
            
            if (triggerCallbacks) {
                if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(onDidFailToRegisterForRemoteNotificationsWithError:)]) {
                    [[PWManagerBridge shared].delegate performSelectorOnMainThread:@selector(onDidFailToRegisterForRemoteNotificationsWithError:) withObject:error waitUntilDone:NO];
                }
                
                if (_registrationHandler) {
                    _registrationHandler(nil, error);
                }
            }
        }
    }];
}

- (void)unregisterDeviceWithCompletion:(void (^)(NSError *))completion  {
    [PWPreferences preferences].lastRegTime = nil;
    [_requestManager sendRequest:[PWUnregisterDeviceRequest new] completion:^(NSError *error) {
        if (error == nil) {
            [PWPreferences preferences].pushToken = nil;
            [PushwooshLog pushwooshLog:PW_LL_INFO
                             className:self
                               message:@"Unregistered for push notifications"];
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:@"Unregistering for push notifications failed"];
        }
        
        if (completion) {
            completion(error);
        }
    }];
}

- (void)handlePushRegistrationString:(NSString *)deviceID withDifferentProvider:(BOOL)isOn {
    [self handlePushRegistrationString:deviceID];
}

- (void)handlePushRegistrationString:(NSString *)deviceID {
    [PWPreferences preferences].pushToken = deviceID;
    
    [self sendDevTokenToServer:deviceID];
}

- (void)handlePushRegistration:(NSData *)devToken {
    NSMutableString *deviceID = [NSMutableString stringWithCapacity:devToken.length];
    const uint8_t *tokenDataPtr = (const uint8_t *)devToken.bytes;
    
    for (NSUInteger i = 0; i < devToken.length; ++i) {
        [deviceID appendString:[NSString stringWithFormat:@"%02hhx", tokenDataPtr[i]]];
    }
    
    if ([self resetLastRegTimeIfNeeded:deviceID]) {
        [PWPreferences preferences].pushToken = deviceID;
        [PWPreferences preferences].registrationEverOccured = YES;
    }
    
    [self sendDevTokenToServer:deviceID];
}

- (BOOL)resetLastRegTimeIfNeeded:(NSString *)pushToken {
    if (![[PWPreferences preferences].pushToken isEqualToString:pushToken]) {
        [PWPreferences preferences].lastRegTime = NSDate.distantPast;
        return YES;
    } else {
        return NO;
    }
}

- (void)handlePushRegistrationFailure:(NSError *)error {
    if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(onDidFailToRegisterForRemoteNotificationsWithError:)]) {
        [[PWManagerBridge shared].delegate performSelectorOnMainThread:@selector(onDidFailToRegisterForRemoteNotificationsWithError:) withObject:error waitUntilDone:NO];
    }
    
    if (_registrationHandler) {
        _registrationHandler(nil, error);
    }
}

- (void)processUserInfo:(NSDictionary *)userInfo {
    NSNumber *log = userInfo[@"log"];

    if ([log isKindOfClass:[NSNumber class]]) {
        [PWPreferences preferences].logLevel = (unsigned int)log.integerValue;
    }

    [self processActionUserInfo:userInfo];
}

- (void)processActionUserInfo:(NSDictionary *)userInfo {
    NSString *htmlPageId = userInfo[@"h"];
    NSString *linkUrl = userInfo[@"l"];
    NSString *customHtmlPageId = userInfo[@"r"];
    NSDictionary *richMedia = userInfo[@"rm"];
    
#if TARGET_OS_IOS || TARGET_OS_OSX
    if (htmlPageId) {
        [[PWManagerBridge shared].richPushManager showPushPage:htmlPageId];
    } else if (customHtmlPageId) {
        [[PWManagerBridge shared].richPushManager showCustomPushPageWithURLString:customHtmlPageId];
    } else if (richMedia) {
        [[PWManagerBridge shared].inAppMessagesManager presentRichMediaFromPush:userInfo];
    }
#endif
    
    if (linkUrl && [[PWConfig config] preHandleNotificationsWithUrl]) {
        if ([self isSilentPush:userInfo] && ![[PWConfig config] acceptedDeepLinkForSilentPush])
            return;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [PWUtils openUrl:[NSURL URLWithString:linkUrl]];
        });
    }
}

- (BOOL)isSilentPush:(NSDictionary *)userInfo {
    return [[[self getApnPayload:userInfo] objectForKey:@"content-available"] boolValue];
}

- (NSDictionary *)startPushInfoFromInfoDictionary:(NSDictionary *)userInfo {
    return [_notificationManagerCompat startPushInfoFromInfoDictionary:userInfo];
}

- (BOOL)preHandlePushReceived:(NSDictionary *)userInfo onStart:(BOOL)onStart {
    return NO;
}

- (BOOL)showForegroundAlert:(NSDictionary *)userInfo onStart:(BOOL)onStart {
    return NO;
}

- (BOOL)handlePushReceived:(NSDictionary *)userInfo autoAcceptAllowed:(BOOL)autoAcceptAllowed {
    if (![userInfo isKindOfClass:[NSDictionary class]])
        return NO;
    
    NSDictionary *pushStartDictionary = [self startPushInfoFromInfoDictionary:userInfo];
    BOOL isPushFromBackground = pushStartDictionary != nil || [self isAppInBackground];
    
    if (pushStartDictionary) {
        userInfo = pushStartDictionary;
    }
    
    if (![PWMessage isPushwooshMessage:userInfo]) {
        return NO;
    }
    
    NSDictionary *pushDict = userInfo[@"aps"];
    if (!pushDict || ![pushDict isKindOfClass:[NSDictionary class]])
        return NO;
    
    if (pushStartDictionary) {
        [PWManagerBridge shared].launchNotification = pushStartDictionary;
    }
    
    NSString *hash = userInfo[@"p"];
    //check hash valid
    if (hash != nil && ![hash isKindOfClass:[NSString class]]) {
        return NO;
    }
    
    if (![self checkDuplicate:userInfo]) {
        return NO;
    }
    
    [self dispatchInboxPushIfNeeded:userInfo];
    
#if TARGET_OS_IPHONE
    if (![PWManagerBridge shared].showPushnotificationAlert && _config.sendPushStatIfAlertsDisabled && !isPushFromBackground && ![PWMessage isContentAvailablePush:userInfo]) {
        [[PWManagerBridge shared].dataManager sendStatsForPush:userInfo];
    }
#else
    [[PWManagerBridge shared].dataManager sendStatsForPush:userInfo];
#endif
    
    [self preHandlePushReceived:userInfo onStart:isPushFromBackground];

    if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(onPushReceived:withNotification:onStart:)]) {
        PWManagerBridge *bridge = [PWManagerBridge shared];
        id sender = bridge.delegateSender ?: bridge;
        NSMethodSignature *signature = [bridge.delegate methodSignatureForSelector:@selector(onPushReceived:withNotification:onStart:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setSelector:@selector(onPushReceived:withNotification:onStart:)];
        [invocation setTarget:bridge.delegate];
        [invocation setArgument:&sender atIndex:2];
        [invocation setArgument:&userInfo atIndex:3];
        [invocation setArgument:&isPushFromBackground atIndex:4];
        [invocation invoke];
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        PWMessage *message = [[PWMessage alloc] initWithPayload:userInfo foreground:!isPushFromBackground];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(pushwoosh:onMessageReceived:)]) {
                id delegate = [PWManagerBridge shared].delegate;
                SEL selector = @selector(pushwoosh:onMessageReceived:);
                NSMethodSignature *signature = [delegate methodSignatureForSelector:selector];
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                [invocation setSelector:selector];
                [invocation setTarget:delegate];

                id bridge = [PWManagerBridge shared];
                [invocation setArgument:&bridge atIndex:2];
                [invocation setArgument:&message atIndex:3];
                [invocation invoke];

                [PushwooshLog pushwooshLog:PW_LL_INFO
                                 className:self
                                   message:[NSString stringWithFormat:@"Method 'pushwoosh:onMessageReceived:' was called with payload: %@", userInfo]];
            }
            
            if (autoAcceptAllowed && ![self showForegroundAlert:userInfo onStart:isPushFromBackground]) {
                if (isPushFromBackground) {
                    [self handlePushAccepted:userInfo onStart:isPushFromBackground];
                } else {
                    [self processUserInfo:userInfo];
                }
            }
        });
    });
    
    return YES;
}

- (BOOL)dispatchInboxPushIfNeeded:(NSDictionary *)userInfo {
    return NO;
}

- (BOOL)dispatchActionInboxPushIfNeeded:(NSDictionary *)userInfo {
    return NO;
}

- (BOOL)checkDuplicate:(NSDictionary *)userInfo {
    if ([userInfo isEqualToDictionary:_lastPushMessage])
        return NO;
    _lastPushMessage = userInfo;
    return YES;
}

- (BOOL)handlePushAccepted:(NSDictionary *)userInfo onStart:(BOOL)onStart {
    [self processUserInfo:userInfo];
    [self dispatchActionInboxPushIfNeeded:userInfo];
    
#if TARGET_OS_IPHONE
    [[PWManagerBridge shared].dataManager sendStatsForPush:userInfo];
#endif
    
    if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(onPushAccepted:withNotification:onStart:)]) {
        PWManagerBridge *bridge = [PWManagerBridge shared];
        NSMethodSignature *signature = [bridge.delegate methodSignatureForSelector:@selector(onPushAccepted:withNotification:onStart:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setSelector:@selector(onPushAccepted:withNotification:onStart:)];
        [invocation setTarget:bridge.delegate];
        [invocation setArgument:&bridge atIndex:2];
        [invocation setArgument:&userInfo atIndex:3];
        [invocation setArgument:&onStart atIndex:4];
        [invocation invoke];
    } else if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(onPushAccepted:withNotification:)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        PWManagerBridge *bridge = [PWManagerBridge shared];
        NSMethodSignature *signature = [bridge.delegate methodSignatureForSelector:@selector(onPushAccepted:withNotification:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setSelector:@selector(onPushAccepted:withNotification:)];
        [invocation setTarget:bridge.delegate];
        [invocation setArgument:&bridge atIndex:2];
        [invocation setArgument:&userInfo atIndex:3];
        [invocation invoke];
#pragma clang diagnostic pop
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        PWMessage *message = [[PWMessage alloc] initWithPayload:userInfo foreground:!onStart];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(pushwoosh:onMessageOpened:)]) {
                id delegate = [PWManagerBridge shared].delegate;
                SEL selector = @selector(pushwoosh:onMessageOpened:);
                NSMethodSignature *signature = [delegate methodSignatureForSelector:selector];
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                [invocation setSelector:selector];
                [invocation setTarget:delegate];

                id bridge = [PWManagerBridge shared];
                [invocation setArgument:&bridge atIndex:2];
                [invocation setArgument:&message atIndex:3];
                [invocation invoke];
            }
        });
    });
    
    return YES;
}

- (NSDictionary *)getApnPayload:(NSDictionary *)pushNotification {
    return pushNotification[@"aps"];
}

- (NSString *)getCustomPushData:(NSDictionary *)pushNotification {
    NSString* customData = pushNotification[@"u"];
    if (![customData isKindOfClass:[NSString class]]) {
        return nil;
    }
    
    return customData;
}

- (NSDictionary *)getCustomPushDataAsNSDict:(NSDictionary *)pushNotification {
    NSString *userdataStr = [self getCustomPushData:pushNotification];
    if (!userdataStr)
        return nil;
    
    NSDictionary *userdata = [NSJSONSerialization JSONObjectWithData:[userdataStr dataUsingEncoding:NSUTF8StringEncoding]
                                                             options:NSJSONReadingMutableContainers
                                                               error:nil];
    
    if (![userdata isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    return userdata;
}

- (void)registerTestDevice {
    PWRegisterTestDeviceRequest *request = [[PWRegisterTestDeviceRequest alloc] init];
    request.token = [PWPreferences preferences].pushToken;
    request.name = [PWUtils deviceName];
    request.desc = @"Imported from the app";
    
    [_requestManager sendRequest:request completion:^(NSError *error) {
        if (error == nil) {
            [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:@"Registered test device"];
            [PWUtils showAlertWithTitle:@"Success" message:@"Test device has been registered."];
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"Registering test device failed"];
            NSString *errorMsg = [NSString stringWithFormat:@"Test device registration has been failed. %@", error.description];
            [PWUtils showAlertWithTitle:@"Error" message:errorMsg];
        }
    }];
}

- (void)setReverseProxy:(NSString *)url {
    [_requestManager setReverseProxyUrl:url];
}

- (void)disableReverseProxy {
    [_requestManager disableReverseProxy];
}

- (void)registerNumber:(NSString *)number forPlatform:(PWPlatform)platform {
    [_requestManager sendRequest:[self requestParameters:number platform:platform] completion:^(NSError *error) {
        [[PWPreferences preferences] setCustomTags:nil];
        
        if (error == nil) {
            [PushwooshLog pushwooshLog:PW_LL_INFO
                             className:self
                               message:[NSString stringWithFormat:@"Registered for %@ notifications: %@", (platform == Whatsapp) ? @"WhatsApp" : @"SMS", number]];
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:[NSString stringWithFormat:@"Registration for %@ notifications failed", (platform == Whatsapp) ? @"WhatsApp" : @"SMS"]];
        }
    }];
}

- (PWRegisterDeviceRequest *)requestParameters:(NSString *)token platform:(PWPlatform)platform {
    _request = [[PWRegisterDeviceRequest alloc] init];
    _request.platform = platform;
    _request.token = token;
    _request.customTags = [[PWPreferences preferences] customTags];
    
    return _request;
}

- (void)registerWhatsappNumber:(NSString *)number {
    [self registerNumber:number forPlatform:Whatsapp];
}

- (void)registerSmsNumber:(NSString *)number {
    [self registerNumber:number forPlatform:SMS];
}

@end
