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

@interface PWUserNotificationCenterDelegate()

@property (nonatomic, strong) PWPushNotificationsManager *notificationManager;
@property (nonatomic) NSString *lastHash;

@end


@implementation PWUserNotificationCenterDelegate

- (instancetype)initWithNotificationManager:(PWPushNotificationsManager*)manager {
	self = [super init];
	if (self) {
		_notificationManager = manager;
	}
	return self;
}

#if TARGET_OS_IOS || TARGET_OS_WATCH

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    if ([self isRemoteNotification:notification] && [PWMessage isPushwooshMessage:notification.request.content.userInfo]) {
        UNMutableNotificationContent *content = notification.request.content.mutableCopy;
        NSMutableDictionary *userInfo = content.userInfo.mutableCopy;
        userInfo[@"pw_push"] = @(YES);
        
        content.userInfo = userInfo;
        
        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:notification.request.identifier content:content trigger:nil];
        
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
        
        //newsstand push
        if (![PWMessage isContentAvailablePush:userInfo]) {
             [_notificationManager handlePushReceived:[self pushPayloadFromContent:content] autoAcceptAllowed:NO];
        }
        
        completionHandler(UNNotificationPresentationOptionNone);
    } else if ([PWManagerBridge shared].showPushnotificationAlert || [notification.request.content.userInfo objectForKey:@"pw_push"] == nil) {
        UNMutableNotificationContent *content = notification.request.content.mutableCopy;

        if ([_lastHash isEqualToString:content.userInfo[@"p"]]) {
            completionHandler(UNNotificationPresentationOptionNone);
        } else {
            _lastHash = content.userInfo[@"p"];
            completionHandler(UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound);
        }
    } else {
        completionHandler(UNNotificationPresentationOptionNone);
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler {
    dispatch_block_t handlePushAcceptanceBlock = ^{
        if (![response.actionIdentifier isEqualToString:UNNotificationDismissActionIdentifier]) {
            if (![response.actionIdentifier isEqualToString:UNNotificationDefaultActionIdentifier] && [[PWManagerBridge shared].delegate respondsToSelector:@selector(onActionIdentifierReceived:withNotification:)]) {
                id delegate = [PWManagerBridge shared].delegate;
                SEL selector = NSSelectorFromString(@"onActionIdentifierReceived:withNotification:");
                NSMethodSignature *signature = [delegate methodSignatureForSelector:selector];
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                [invocation setSelector:selector];
                [invocation setTarget:delegate];

                NSString *actionId = response.actionIdentifier;
                NSDictionary *notification = [self pushPayloadFromContent:response.notification.request.content];
                [invocation setArgument:&actionId atIndex:2];
                [invocation setArgument:&notification atIndex:3];
                [invocation invoke];
            }
            NSDictionary *userInfo = [self pushPayloadFromContent:response.notification.request.content];
            NSMutableDictionary *userInfoWithActionIdentifier = [NSMutableDictionary dictionaryWithDictionary:userInfo];
            [userInfoWithActionIdentifier addEntriesFromDictionary:@{@"actionIdentifier": response.actionIdentifier}];
            [_notificationManager handlePushAccepted:userInfoWithActionIdentifier onStart:_notificationManager.isAppInBackground];
        }
    };
    
    if ([self isRemoteNotification:response.notification]  && [PWMessage isPushwooshMessage:response.notification.request.content.userInfo]) {
        if (![PWMessage isContentAvailablePush:response.notification.request.content.userInfo]) {
            [_notificationManager handlePushReceived:[self pushPayloadFromContent:response.notification.request.content] autoAcceptAllowed:NO];
        }
        
        handlePushAcceptanceBlock();
    } else if ([response.notification.request.content.userInfo objectForKey:@"pw_push"]) {
        handlePushAcceptanceBlock();
    }

    completionHandler();
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
    NSLog(@"userNotificationCenter:didReceiveRemoteNotification: %@", notification.userInfo);
    
    if (notification.remote) {
        [_notificationManager handlePushReceived:notification.userInfo autoAcceptAllowed:NO];
    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    NSLog(@"userNotificationCenter:didActivateNotification: %@", notification.userInfo);

    if (notification.remote) {
        [_notificationManager handlePushAccepted:notification.userInfo onStart:_notificationManager.isAppInBackground];
    }
}

#endif

@end
