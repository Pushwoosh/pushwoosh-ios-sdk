//
//  PWAppLifecycleTrackingManager.m
//  Pushwoosh
//
//  Created by Fectum on 01/04/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWAppLifecycleTrackingManager.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PWDataManager.h>
#import <PushwooshCore/PWInAppManager.h>
#import <PushwooshCore/PWServerCommunicationManager.h>
#import <objc/runtime.h>
#import "PWPreferences.h"
#import "PWUtils.h"
#import "PWSystemCommandDispatcher.h"
#import "PWScreenTrackingManager.h"

static NSTimeInterval const kPWApplicationMinimizedDebounce = 1.0;

#if TARGET_OS_IOS || TARGET_OS_TV
#import <UIKit/UIKit.h>
#define PW_APPLICATION_CLASS UIApplication
#define PW_APPLICATION_STATE_BACKGROUND UIApplicationStateBackground
#define PW_NOTIFICATION_DID_BECOME_ACTIVE UIApplicationDidBecomeActiveNotification
#define PW_NOTIFICATION_DID_ENTER_BACKGROUND UIApplicationDidEnterBackgroundNotification
#elif TARGET_OS_OSX
#import <AppKit/AppKit.h>
#define PW_APPLICATION_CLASS NSApplication
#define PW_APPLICATION_STATE_BACKGROUND NSApplicationStateInactive
#define PW_NOTIFICATION_DID_BECOME_ACTIVE NSApplicationDidBecomeActiveNotification
#define PW_NOTIFICATION_DID_ENTER_BACKGROUND NSApplicationDidResignActiveNotification
#endif

NSString * const defaultApplicationOpenedEvent = @"PW_ApplicationOpen";
NSString * const defaultApplicationClosedEvent = @"PW_ApplicationMinimized";

@interface PWAppLifecycleTrackingManager ()

@property (nonatomic) BOOL appInForeground;
@property (nonatomic) NSString *trackingAppCode;
@property (nonatomic) BOOL initialDefaultOpenEventSent;
@property (nonatomic) BOOL applicationDidBecomeActive;
@property (nonatomic) BOOL serverCommunicationEnabled;
@property (nonatomic, strong, readwrite) NSDate *foregroundTimestamp;
@property (nonatomic, assign, readwrite) NSTimeInterval foregroundMonotonicTimestamp;

@end

@implementation PWAppLifecycleTrackingManager {
    id _communicationStartedHandler;
    dispatch_block_t _pendingMinimizedBlock;
    BOOL _minimizedPending;
#if TARGET_OS_IOS
    UIBackgroundTaskIdentifier _minimizedBgTask;
#endif
}

- (instancetype)init {
    if (self = [super init]) {
#if TARGET_OS_IOS
        _minimizedBgTask = UIBackgroundTaskInvalid;
#endif
    }
    return self;
}

+ (instancetype)sharedManager {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)startTracking {
    [[PWPreferences preferences] addObserver:self forKeyPath:@"appCode" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"appCode"]) {
        NSString *appCode = [PWPreferences preferences].appCode;

        if (appCode && ![appCode isEqualToString:@""] && ![[PWPreferences preferences].appCode isEqualToString:_trackingAppCode]) {
            _trackingAppCode = [PWPreferences preferences].appCode;
            _initialDefaultOpenEventSent = NO;
            // without dispatch_async this method called too early from +pushManager method
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startSendingEvents];
            });
        }
    }
}

- (void)dealloc {
    [[PWPreferences preferences] removeObserver:self forKeyPath:@"appCode"];
}

- (void)startSendingEvents {
    if ([PW_APPLICATION_CLASS sharedApplication].applicationState != PW_APPLICATION_STATE_BACKGROUND) {
        // Process system push from launch notification before sending applicationOpen
        NSDictionary *launchNotification = [PWManagerBridge shared].launchNotification;
        if (launchNotification) {
            [[PWSystemCommandDispatcher shared] processUserInfo:launchNotification];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [[PWManagerBridge shared].dataManager sendAppOpenWithCompletion:nil];
        });

        _foregroundTimestamp = [NSDate date];
        _foregroundMonotonicTimestamp = [NSProcessInfo processInfo].systemUptime;
        _appInForeground = YES;

        if (_defaultAppOpenAllowed == YES && !_initialDefaultOpenEventSent) {
            [self sendDefaultEvent:defaultApplicationOpenedEvent];
            _initialDefaultOpenEventSent = YES;
        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onApplicationOpen) name:PW_NOTIFICATION_DID_BECOME_ACTIVE object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onApplicationClosed) name:PW_NOTIFICATION_DID_ENTER_BACKGROUND object:nil];

    // wait until server communication is allowed before sending appOpen
    if (![[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        [self addServerCommunicationStartedObserver];
    } else {
        _serverCommunicationEnabled = YES;
    }
}

- (void)addServerCommunicationStartedObserver {
    if (!_communicationStartedHandler) {
        _communicationStartedHandler = [[NSNotificationCenter defaultCenter] addObserverForName:kPWServerCommunicationStarted object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {

            _serverCommunicationEnabled = YES;
            [[NSNotificationCenter defaultCenter] removeObserver:_communicationStartedHandler];
            _communicationStartedHandler = nil;
            [self sendAppOpen];
        }];
    }
}

- (void)onApplicationOpen {
    if (_minimizedPending) {
        [self cancelMinimizedBlock];
        [PWScreenTrackingManager sharedManager].suppressScreenOpened = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            [PWScreenTrackingManager sharedManager].suppressScreenOpened = NO;
        });
        return;
    }

    _applicationDidBecomeActive = YES;
    _foregroundTimestamp = [NSDate date];
    _foregroundMonotonicTimestamp = [NSProcessInfo processInfo].systemUptime;
    [self sendAppOpen];
}

- (void)sendAppOpen {
    if (!_serverCommunicationEnabled || !_applicationDidBecomeActive) {
        return;
    }
    if (!_appInForeground) {
        _appInForeground = YES;

        dispatch_async(dispatch_get_main_queue(), ^{
            [[PWManagerBridge shared].dataManager sendAppOpenWithCompletion:nil];
        });

        if (_defaultAppOpenAllowed == YES) {
            [self sendDefaultEvent: defaultApplicationOpenedEvent];
            [[PWScreenTrackingManager sharedManager] emitScreenOpenForCurrentScreen];
        }
    }
}

- (void)sendDefaultEvent: (NSString *) event{
    NSDictionary *attrs = @{
        @"device_type": @1,
        @"application_version": [PWUtils appVersion],
    };
    [[[PWManagerBridge shared] inAppManager] postEvent:event withAttributes:attrs completion:nil];
}

- (void)onApplicationClosed {
    _appInForeground = NO;

    if (_defaultAppClosedAllowed == NO) return;

    [self cancelMinimizedBlock];
    _minimizedPending = YES;

    [self beginMinimizedBackgroundTask];

    __weak typeof(self) weakSelf = self;
    _pendingMinimizedBlock = dispatch_block_create(0, ^{
        [weakSelf fireMinimizedEvent];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kPWApplicationMinimizedDebounce * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   _pendingMinimizedBlock);
}

- (void)fireMinimizedEvent {
    if (!_minimizedPending) return;
    _minimizedPending = NO;
    _pendingMinimizedBlock = nil;
    [self sendDefaultEvent:defaultApplicationClosedEvent];
    [self endMinimizedBackgroundTask];
}

- (void)cancelMinimizedBlock {
    if (_pendingMinimizedBlock) {
        dispatch_block_cancel(_pendingMinimizedBlock);
        _pendingMinimizedBlock = nil;
    }
    _minimizedPending = NO;
    [self endMinimizedBackgroundTask];
}

- (void)beginMinimizedBackgroundTask {
#if TARGET_OS_IOS
    if (_minimizedBgTask != UIBackgroundTaskInvalid) return;

    __weak typeof(self) weakSelf = self;
    _minimizedBgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"PWApplicationMinimized"
                                                                    expirationHandler:^{
        [weakSelf onMinimizedBackgroundTaskExpired];
    }];
#endif
}

- (void)onMinimizedBackgroundTaskExpired {
#if TARGET_OS_IOS
    if (_pendingMinimizedBlock) {
        dispatch_block_cancel(_pendingMinimizedBlock);
        _pendingMinimizedBlock = nil;
    }
    _minimizedPending = NO;
    [self endMinimizedBackgroundTask];
#endif
}

- (void)endMinimizedBackgroundTask {
#if TARGET_OS_IOS
    if (_minimizedBgTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:_minimizedBgTask];
        _minimizedBgTask = UIBackgroundTaskInvalid;
    }
#endif
}

- (void)setDefaultAppOpenAllowed:(BOOL)defaultAppOpenAllowed {
    _defaultAppOpenAllowed = defaultAppOpenAllowed;

    if (defaultAppOpenAllowed && !_initialDefaultOpenEventSent) {
         if ([PW_APPLICATION_CLASS sharedApplication].applicationState != PW_APPLICATION_STATE_BACKGROUND) {
             [self sendDefaultEvent: defaultApplicationOpenedEvent];
             _initialDefaultOpenEventSent = YES;
         }
    }
}

@end
