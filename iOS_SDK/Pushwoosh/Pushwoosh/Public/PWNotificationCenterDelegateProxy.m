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
#if TARGET_OS_IOS || TARGET_OS_TV
@property (nonatomic, weak) id<UNUserNotificationCenterDelegate> preservedExistingDelegate;
- (NSArray<id<UNUserNotificationCenterDelegate>> *)activeDelegates;
- (void)runCompletionFallback:(dispatch_block_t)fallback whenForwarded:(BOOL)forwarded;
#endif

@end

#if TARGET_OS_IOS || TARGET_OS_TV
/*
 Delay before the proxy force-completes a notification that a forwarded delegate received but never
 completed (a misbehaving third-party SDK). Long enough for a well-behaved async delegate to finish
 first; overridable from tests via setCompletionFallbackDelayForTesting:.
 */
static NSTimeInterval sCompletionFallbackDelay = 4.0;
#endif

@implementation PWNotificationCenterDelegateProxy

- (instancetype)initWithNotificationManager:(PWPushNotificationsManager *)manager {
    _delegates = [NSMutableArray new];
    _defaultNotificationCenterDelegate = [[PWUserNotificationCenterDelegate alloc] initWithNotificationManager:manager];
#if TARGET_OS_IOS || TARGET_OS_TV
    if ([UNUserNotificationCenter class]) {
        [self preserveExistingDelegate:UNUserNotificationCenter.currentNotificationCenter.delegate];
        UNUserNotificationCenter.currentNotificationCenter.delegate = self;
    }
#elif TARGET_OS_OSX
    if ([NSUserNotificationCenter class]) {
        NSUserNotificationCenter.defaultUserNotificationCenter.delegate = self;
    }
#endif
    
    return self;
}
#if TARGET_OS_IOS || TARGET_OS_TV
- (void)addNotificationCenterDelegate:(id<UNUserNotificationCenterDelegate>)delegate {
    [_delegates addObject:delegate];
}

- (void)preserveExistingDelegate:(id<UNUserNotificationCenterDelegate>)existingDelegate {
    /*
     Keep a WEAK reference to a delegate installed before Pushwoosh (another push SDK or the host app)
     so it keeps receiving callbacks through the proxy instead of being silently orphaned when the
     proxy takes over. Weak on purpose: UNUserNotificationCenter holds its delegate weakly, so the
     proxy must not silently extend that object's lifetime. Internal seam: callable directly from
     tests because UNUserNotificationCenter is unavailable in a headless unit-test host.
     */
    if (existingDelegate && existingDelegate != self) {
        self.preservedExistingDelegate = existingDelegate;
    }
}

- (NSArray<id<UNUserNotificationCenterDelegate>> *)activeDelegates {
    /*
     Explicitly added delegates (held strongly in _delegates) plus the preserved pre-Pushwoosh
     delegate (held weakly, included only while still alive). The snapshot pins the weak delegate for
     the duration of a callback and makes iteration safe against concurrent mutation.
     */
    id<UNUserNotificationCenterDelegate> preserved = self.preservedExistingDelegate;
    if (preserved == nil || [_delegates containsObject:preserved]) {
        return [_delegates copy];
    }
    NSMutableArray *all = [_delegates mutableCopy];
    [all addObject:preserved];
    return all;
}

- (void)runCompletionFallback:(dispatch_block_t)fallback whenForwarded:(BOOL)forwarded {
    /*
     If no delegate received the handler, complete immediately so the notification isn't left hanging.
     If a delegate did receive it, defer: a well-behaved async delegate calls the real handler first
     (the exactly-once guard then makes this a no-op and preserves its options), while a delegate that
     never calls the handler is still recovered after the delay.
     */
    if (!forwarded) {
        fallback();
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(sCompletionFallbackDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), fallback);
    }
}

+ (void)setCompletionFallbackDelayForTesting:(NSTimeInterval)delay {
    sCompletionFallbackDelay = delay;
}
#endif

#if TARGET_OS_IOS
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    /*
     The system requires this completion handler to run exactly once. We forward to Pushwoosh's
     default delegate and to every added delegate, so we hand each of them a guarded wrapper that
     calls the real handler only on the first invocation — preventing the multiple-call crash when
     more than one delegate responds (e.g. Pushwoosh + Firebase).
     */
    __block BOOL handlerCalled = NO;
    void (^safeCompletionHandler)(UNNotificationPresentationOptions) = ^(UNNotificationPresentationOptions options) {
        @synchronized (self) {
            if (handlerCalled) {
                return;
            }
            handlerCalled = YES;
        }
        completionHandler(options);
    };

    BOOL forwarded = NO;

    if ([PWMessage isPushwooshMessage:notification.request.content.userInfo]) {
        [_defaultNotificationCenterDelegate userNotificationCenter:center willPresentNotification:notification withCompletionHandler:safeCompletionHandler];
        forwarded = YES;
    }

    //forward only first pushwoosh notification (not local)
    if (notification.request.content.userInfo[@"pw_push"] == nil) {
        for (id delegate in [self activeDelegates]) {
            if ([delegate respondsToSelector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)]) {
                [delegate userNotificationCenter:center willPresentNotification:notification withCompletionHandler:safeCompletionHandler];
                forwarded = YES;
            }
        }
    }

    [self runCompletionFallback:^{ safeCompletionHandler(UNNotificationPresentationOptionNone); } whenForwarded:forwarded];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)(void))completionHandler {
    /*
     Same exactly-once guard as willPresentNotification: the response is forwarded to Pushwoosh's
     default delegate and to every added delegate, so a shared guarded wrapper ensures the system
     completion handler fires only once even when several delegates respond.
     */
    __block BOOL handlerCalled = NO;
    void (^safeCompletionHandler)(void) = ^{
        @synchronized (self) {
            if (handlerCalled) {
                return;
            }
            handlerCalled = YES;
        }
        completionHandler();
    };

    BOOL forwarded = NO;

    if ([PWMessage isPushwooshMessage:response.notification.request.content.userInfo]) {
        [_defaultNotificationCenterDelegate userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:safeCompletionHandler];
        forwarded = YES;
    }

    for (id delegate in [self activeDelegates]) {
        if ([delegate respondsToSelector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)]) {
            [delegate userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:safeCompletionHandler];
            forwarded = YES;
        }
    }

    [self runCompletionFallback:^{ safeCompletionHandler(); } whenForwarded:forwarded];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(nullable UNNotification *)notification {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wpartial-availability"
    for (id delegate in [self activeDelegates]) {
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
