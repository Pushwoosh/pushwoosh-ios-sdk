//
//  PWAppLifecycleTrackingManager.m
//  Pushwoosh
//
//  Created by Fectum on 01/04/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWAppLifecycleTrackingManager.h"
#import <UIKit/UIKit.h>
#import "PWInAppManager.h"
#import "Pushwoosh+Internal.h"
#import <objc/runtime.h>
#import "PWPreferences.h"
#import "PWUtils.h"

NSString * const defaultApplicationOpenedEvent = @"PW_ApplicationOpen";
NSString * const defaultApplicationClosedEvent = @"PW_ApplicationMinimized";

@interface PWAppLifecycleTrackingManager ()

@property (nonatomic) BOOL appInForeground;
@property (nonatomic) NSString *trackingAppCode;
@property (nonatomic) BOOL initialDefaultOpenEventSent;
@property (nonatomic) BOOL applicationDidBecomeActive;
@property (nonatomic) BOOL serverCommunicationEnabled;

@end

@implementation PWAppLifecycleTrackingManager {
    id _communicationStartedHandler;
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
    [[PWSettings settings] addObserver:self forKeyPath:@"appCode" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"appCode"]) {
        NSString *appCode = [PWSettings settings].appCode;
        
        if (appCode && ![appCode isEqualToString:@""] && ![[PWSettings settings].appCode isEqualToString:_trackingAppCode]) {
            _trackingAppCode = [PWSettings settings].appCode;
            _initialDefaultOpenEventSent = NO;
            // without dispatch_async this method called too early from +pushManager method
            dispatch_async(dispatch_get_main_queue(), ^{
                [self startSendingEvents];
            });
        }
    }
}

- (void)startSendingEvents {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateBackground) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[Pushwoosh sharedInstance].dataManager sendAppOpenWithCompletion:nil];
        });
        
        _appInForeground = YES;
        
        if (_defaultAppOpenAllowed == YES) {
            _initialDefaultOpenEventSent = YES;
        }
    }
    
    // In iOS 11.4 and iOS 12 there's been changes in the way socket resource reclaim is applied.
    // Socket resource reclaim is now run whenever the app is suspended.
    // At the moment of UIApplicationWillEnterForegroundNotification socket may not be ready yet and request may fail
    // https://github.com/AFNetworking/AFNetworking/issues/4279
    // So we use UIApplicationDidBecomeActiveNotification
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onApplicationOpen) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onApplicationClosed) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
    // wait until server communication is allowed before sending appOpen
    if (![[PWCoreServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        [self addServerCommunicationStartedObserver];
    } else {
        _serverCommunicationEnabled = YES;
    }
}

- (void)addServerCommunicationStartedObserver {
    if (!_communicationStartedHandler) {
        _communicationStartedHandler = [[NSNotificationCenter defaultCenter] addObserverForName:kPWCoreServerCommunicationStarted object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {

            _serverCommunicationEnabled = YES;
            [[NSNotificationCenter defaultCenter] removeObserver:_communicationStartedHandler];
            _communicationStartedHandler = nil;
            [self sendAppOpen];
        }];
    }
}

- (void)onApplicationOpen {
    _applicationDidBecomeActive = YES;
    [self sendAppOpen];
}

- (void)sendAppOpen {
    if (!_serverCommunicationEnabled || !_applicationDidBecomeActive) {
        return;
    }
    if (!_appInForeground) {
        _appInForeground = YES;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[Pushwoosh sharedInstance].dataManager sendAppOpenWithCompletion:nil];
        });
        
        if (_defaultAppOpenAllowed == YES) {
            [self sendDefaultEvent: defaultApplicationOpenedEvent];
        }
    }
}

- (void)sendDefaultEvent: (NSString *) event{
    NSDictionary *attrs = @{
        @"device_type": @1,
        @"application_version": [PWUtils appVersion],
    };
    [[PWInAppManager sharedManager] postEvent:event withAttributes:attrs completion:nil];
}

- (void)onApplicationClosed {
    _appInForeground = NO;

    if (_defaultAppClosedAllowed == YES) {
        [self sendDefaultEvent: defaultApplicationClosedEvent];
    }
}

- (void)setDefaultAppOpenAllowed:(BOOL)defaultAppOpenAllowed {
    _defaultAppOpenAllowed = defaultAppOpenAllowed;
    
    if (defaultAppOpenAllowed && !_initialDefaultOpenEventSent) {
         if (UIApplication.sharedApplication.applicationState != UIApplicationStateBackground) {
             [self sendDefaultEvent: defaultApplicationOpenedEvent];
             _initialDefaultOpenEventSent = YES;
         }
    }
}

@end
