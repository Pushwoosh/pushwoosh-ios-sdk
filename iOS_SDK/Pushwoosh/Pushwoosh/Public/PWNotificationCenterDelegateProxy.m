//
//  PWNotificationCenterDelegateProxy.m
//  Pushwoosh
//
//  Created by Fectum on 28.02.2020.
//  Copyright © 2020 Pushwoosh. All rights reserved.
//

#import "PWUserNotificationCenterDelegate.h"
#import "Pushwoosh+Internal.h"

@interface PWNotificationCenterDelegateProxy ()

@property (nonatomic) NSMutableArray *delegates;

@end

@implementation PWNotificationCenterDelegateProxy

- (instancetype)initWithNotificationManager:(PWPushNotificationsManager *)manager {
    _delegates = [NSMutableArray new];
    _defaultNotificationCenterDelegate = [[PWUserNotificationCenterDelegate alloc] initWithNotificationManager:manager];
#if TARGET_OS_IOS || TARGET_OS_WATCH
    if ([UNUserNotificationCenter class]) {
        UNUserNotificationCenter.currentNotificationCenter.delegate = self;
    }
#elif TARGET_OS_OSX
    if ([NSUserNotificationCenter class]) {
        NSUserNotificationCenter.defaultUserNotificationCenter.delegate = self;
    }
#endif
    
    return self;
}
#if TARGET_OS_IOS || TARGET_OS_WATCH
- (void)addNotificationCenterDelegate:(id<UNUserNotificationCenterDelegate>)delegate {
    [_delegates addObject:delegate];
}
#endif

#if TARGET_OS_IOS || TARGET_OS_WATCH
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    if ([PWMessage isPushwooshMessage:notification.request.content.userInfo]) {
        [_defaultNotificationCenterDelegate userNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];
    }
    
    //forward only first pushwoosh notification (not local)
    if (notification.request.content.userInfo[@"pw_push"] == nil) {
        for (id delegate in _delegates) {
            if ([delegate respondsToSelector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)]) {
                [delegate userNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];
            }
        }
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler {
    if ([PWMessage isPushwooshMessage:response.notification.request.content.userInfo]) {
        [_defaultNotificationCenterDelegate userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:completionHandler];
    }
    
    for (id delegate in _delegates) {
        if ([delegate respondsToSelector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)]) {
            [delegate userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:completionHandler];
        }
    }
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(nullable UNNotification *)notification {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wpartial-availability"
    for (id delegate in _delegates) {
        if ([delegate respondsToSelector:@selector(userNotificationCenter:openSettingsForNotification:)]) {
            [delegate userNotificationCenter:center openSettingsForNotification:notification];
        }
    }
    #pragma clang diagnostic pop
}

#elif TARGET_OS_OSX

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    // FIXME: Need key "pw-msg" in payload to use if else statement
//    if ([PWMessage isPushwooshMessage:notification.userInfo]) {
        [_defaultNotificationCenterDelegate userNotificationCenter:center didActivateNotification:notification];
//    }
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didDeliverNotification:(NSUserNotification *)notification {
    // FIXME: Need key "pw-msg" in payload to use if else statement
//    if ([PWMessage isPushwooshMessage:notification.userInfo]) {
        [_defaultNotificationCenterDelegate userNotificationCenter:center didDeliverNotification:notification];
//    }
}

#endif

@end
