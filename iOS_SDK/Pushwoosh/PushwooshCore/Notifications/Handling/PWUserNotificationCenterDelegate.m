//
//  PWUserNotificationCenterDelegate.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 14/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWUserNotificationCenterDelegate.h"
#import "PWMessage+Internal.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWActionButton.h>
#import <PushwooshCore/PWActionButtonsParser.h>

/// iOS ends the background launch as soon as the response handler returns; this keeps a request that
/// never answers from taking the handler down with it.
static const NSTimeInterval kPWActionButtonResponseTimeout = 20;

@interface PWUserNotificationCenterDelegate()

@property (nonatomic, strong) PWPushNotificationsManager *notificationManager;
@property (nonatomic) NSString *lastHash;
/// How long a background button's response waits for its statistics.
@property (nonatomic) NSTimeInterval actionButtonResponseTimeout;

@end


@implementation PWUserNotificationCenterDelegate

- (instancetype)initWithNotificationManager:(PWPushNotificationsManager*)manager {
	self = [super init];
	if (self) {
		_notificationManager = manager;
		_actionButtonResponseTimeout = kPWActionButtonResponseTimeout;
	}
	return self;
}

#if TARGET_OS_IOS

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    if ([self isRemoteNotification:notification] && [PWMessage isPushwooshMessage:notification.request.content.userInfo]) {
        UNMutableNotificationContent *content = notification.request.content.mutableCopy;
        NSMutableDictionary *userInfo = content.userInfo.mutableCopy;
        userInfo[@"pw_push"] = @(YES);

        content.userInfo = userInfo;

        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:notification.request.identifier content:content trigger:nil];

        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];

        if (![PWMessage isSilentPush:userInfo]) {
            [_notificationManager handlePushReceived:[self pushPayloadFromContent:content] autoAcceptAllowed:NO];
        }

        completionHandler(UNNotificationPresentationOptionNone);
    } else if ([PWManagerBridge shared].showPushnotificationAlert || [notification.request.content.userInfo objectForKey:@"pw_push"] == nil) {
        UNMutableNotificationContent *content = notification.request.content.mutableCopy;

        if ([_lastHash isEqualToString:content.userInfo[@"p"]]) {
            completionHandler(UNNotificationPresentationOptionNone);
        } else {
            _lastHash = [content.userInfo[@"p"] isKindOfClass:[NSString class]] ? content.userInfo[@"p"] : nil;
            completionHandler(UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound);
        }
    } else {
        completionHandler(UNNotificationPresentationOptionNone);
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler {
    NSDictionary *payload = [self pushPayloadFromContent:response.notification.request.content];
    PWActionButton *button = [PWActionButtonsParser buttonForActionIdentifier:response.actionIdentifier
                                                                  inUserInfo:payload];
    BOOL backgroundButton = button != nil && !button.opensApplication;

    __block BOOL finished = NO;
    /// This method and every completion that can end it run on the main thread, so the guard needs no lock.
    void (^finish)(void) = ^{
        if (finished) {
            return;
        }
        finished = YES;
        completionHandler();
    };

    BOOL (^handlePushAcceptanceBlock)(void) = ^BOOL{
        if ([response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
            return NO;
        }

        if (![response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier] && [[PWManagerBridge shared].delegate respondsToSelector:@selector(onActionIdentifierReceived:withNotification:)]) {
            id delegate = [PWManagerBridge shared].delegate;
            SEL selector = NSSelectorFromString(@"onActionIdentifierReceived:withNotification:");
            NSMethodSignature *signature = [delegate methodSignatureForSelector:selector];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setSelector:selector];
            [invocation setTarget:delegate];

            NSString *actionId = response.actionIdentifier;
            NSDictionary *notification = payload;
            [invocation setArgument:&actionId atIndex:2];
            [invocation setArgument:&notification atIndex:3];
            [invocation invoke];
        }

        if (button != nil) {
            [center removeDeliveredNotificationsWithIdentifiers:@[ response.notification.request.identifier ]];
        }

        NSMutableDictionary *userInfoWithActionIdentifier = [NSMutableDictionary dictionaryWithDictionary:payload];
        [userInfoWithActionIdentifier addEntriesFromDictionary:@{PWActionIdentifierKey: response.actionIdentifier}];
        [self->_notificationManager handlePushAccepted:userInfoWithActionIdentifier
                                               onStart:self->_notificationManager.isAppInBackground
                                            completion:backgroundButton ? finish : nil];
        return backgroundButton;
    };

    BOOL waitsForStats = NO;

    if ([self isRemoteNotification:response.notification] && [PWMessage isPushwooshMessage:response.notification.request.content.userInfo]) {
        if (![PWMessage isSilentPush:response.notification.request.content.userInfo]) {
            [_notificationManager handlePushReceived:payload autoAcceptAllowed:NO opensApplication:!backgroundButton];
        }

        waitsForStats = handlePushAcceptanceBlock();
    } else if ([response.notification.request.content.userInfo objectForKey:@"pw_push"]) {
        waitsForStats = handlePushAcceptanceBlock();
    }

    if (waitsForStats) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.actionButtonResponseTimeout * NSEC_PER_SEC)), dispatch_get_main_queue(), finish);
        return;
    }

    finish();
}

- (BOOL)isRemoteNotification:(UNNotification *)notification {
    return [notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]];
}

- (NSDictionary *)pushPayloadFromContent:(UNNotificationContent *)content {
    return [[content.userInfo objectForKey:@"pw_push"] isKindOfClass:[NSDictionary class]] ? [content.userInfo objectForKey:@"pw_push"] : content.userInfo;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(UNNotification *)notification {
    if ([[PWManagerBridge shared].delegate respondsToSelector:@selector(pushManager:openSettingsForNotification:)]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wpartial-availability"
        id delegate = [PWManagerBridge shared].delegate;
        SEL selector = NSSelectorFromString(@"pushManager:openSettingsForNotification:");
        NSMethodSignature *signature = [delegate methodSignatureForSelector:selector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setSelector:selector];
        [invocation setTarget:delegate];

        id manager = [PWManagerBridge shared];
        [invocation setArgument:&manager atIndex:2];
        [invocation setArgument:&notification atIndex:3];
        [invocation invoke];
        #pragma clang diagnostic pop
    }
}

#elif TARGET_OS_TV
// tvOS doesn't support notification interaction

#else

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"didDeliverNotification: %@", notification.userInfo]];

    if (notification.remote) {
        [_notificationManager handlePushReceived:notification.userInfo autoAcceptAllowed:NO];
    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"didActivateNotification: %@", notification.userInfo]];

    if (notification.remote) {
        [_notificationManager handlePushAccepted:notification.userInfo onStart:_notificationManager.isAppInBackground];
    }
}

#endif

@end
