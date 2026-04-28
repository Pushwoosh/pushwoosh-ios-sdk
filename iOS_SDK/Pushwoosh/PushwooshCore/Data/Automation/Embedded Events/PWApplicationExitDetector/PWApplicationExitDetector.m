//
//  PWApplicationExitDetector.m
//  PushwooshCore
//
//  Created by André Kis on 27.04.26.
//

#if TARGET_OS_IOS

#import "PWApplicationExitDetector.h"
#import <UIKit/UIKit.h>
#import "PWScreenTrackingManager.h"
#import "PWAppLifecycleTrackingManager.h"
#import "PWUtils.h"
#import "PWInAppManager.h"
#import "PWConfig.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PushwooshLog.h>

NSString * const defaultApplicationExitEvent = @"PW_ApplicationExit";

@implementation PWApplicationExitDetector {
    NSTimeInterval _exitTimeout;
    dispatch_block_t _exitBlock;
    NSString *_pendingScreenName;
    NSInteger _pendingSessionDurationSeconds;
    NSInteger _pendingExitTimeoutSeconds;
    BOOL _scheduled;
    UIBackgroundTaskIdentifier _bgTask;
}

+ (instancetype)sharedDetector {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    NSInteger configTimeout = [PWConfig config].applicationExitTimeoutSeconds;
    NSTimeInterval timeout = configTimeout > 0 ? (NSTimeInterval)configTimeout : 0;
    return [self initWithExitTimeout:timeout];
}

- (instancetype)initWithExitTimeout:(NSTimeInterval)timeout {
    if (self = [super init]) {
        _exitTimeout = timeout;
        _bgTask = UIBackgroundTaskInvalid;
    }
    return self;
}

- (void)startTracking {
    _defaultApplicationExitTrackingAllowed = (_exitTimeout > 0);

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

#pragma mark - Lifecycle

- (void)onDidEnterBackground {
    if (!_defaultApplicationExitTrackingAllowed || _exitTimeout <= 0) return;

    [self cancelExitBlock];

    NSInteger effectiveTimeoutSeconds = (NSInteger)_exitTimeout;

    _pendingScreenName = [[PWScreenTrackingManager sharedManager].currentScreenName copy];
    _pendingSessionDurationSeconds = [self computeSessionDurationSeconds];
    _pendingExitTimeoutSeconds = effectiveTimeoutSeconds;

    [self beginBackgroundTask];

    __weak typeof(self) weakSelf = self;
    _exitBlock = dispatch_block_create(0, ^{
        [weakSelf onExitFired];
    });
    _scheduled = YES;

    [PushwooshLog pushwooshLog:PW_LL_INFO
                     className:[self class]
                       message:[NSString stringWithFormat:@"Exit timer scheduled (timeout=%lds)",
                                (long)_pendingExitTimeoutSeconds]];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_exitTimeout * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   _exitBlock);
}

- (void)beginBackgroundTask {
    if (_bgTask != UIBackgroundTaskInvalid) return;

    __weak typeof(self) weakSelf = self;
    _bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"PWApplicationExit"
                                                          expirationHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf onBackgroundTaskExpired];
        });
    }];
}

- (void)onBackgroundTaskExpired {
    if (!_defaultApplicationExitTrackingAllowed || !_scheduled) {
        [self endBackgroundTask];
        return;
    }

    [PushwooshLog pushwooshLog:PW_LL_INFO
                     className:[self class]
                       message:@"Exit timer fired early due to background task expiration"];

    [self cancelExitBlock];
    [self fireExitEvent];
    [self endBackgroundTask];
}

- (void)endBackgroundTask {
    if (_bgTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
        _bgTask = UIBackgroundTaskInvalid;
    }
}

- (void)onDidBecomeActive {
    if (_scheduled) {
        [PushwooshLog pushwooshLog:PW_LL_INFO
                         className:[self class]
                           message:@"Exit timer cancelled (foreground)"];
    }
    [self cancelExitBlock];
    _pendingScreenName = nil;
    _pendingSessionDurationSeconds = 0;
    _pendingExitTimeoutSeconds = 0;
    [self endBackgroundTask];
}

- (void)onExitFired {
    if (!_scheduled) return;
    _scheduled = NO;
    _exitBlock = nil;
    [self fireExitEvent];
    [self endBackgroundTask];
}

- (void)cancelExitBlock {
    if (_exitBlock) {
        dispatch_block_cancel(_exitBlock);
        _exitBlock = nil;
    }
    _scheduled = NO;
}

- (NSInteger)computeSessionDurationSeconds {
    NSTimeInterval foregroundMono = [PWAppLifecycleTrackingManager sharedManager].foregroundMonotonicTimestamp;
    if (foregroundMono <= 0) return 0;
    NSTimeInterval delta = [NSProcessInfo processInfo].systemUptime - foregroundMono;
    if (delta < 0) delta = 0;
    return (NSInteger)round(delta);
}

- (void)fireExitEvent {
    NSInteger timeoutForPayload = _pendingExitTimeoutSeconds > 0 ? _pendingExitTimeoutSeconds : (NSInteger)_exitTimeout;

    NSMutableDictionary *attrs = [@{
        @"device_type": @1,
        @"application_version": [PWUtils appVersion],
        @"session_duration": @(_pendingSessionDurationSeconds),
        @"exit_intent_seconds": @(timeoutForPayload),
    } mutableCopy];

    if (_pendingScreenName) {
        attrs[@"screen_name"] = _pendingScreenName;
    }

    [PushwooshLog pushwooshLog:PW_LL_INFO
                     className:[self class]
                       message:[NSString stringWithFormat:@"PW_ApplicationExit fired (session=%lds, screen=%@, timeout=%lds)",
                                (long)_pendingSessionDurationSeconds,
                                _pendingScreenName ?: @"(nil)",
                                (long)timeoutForPayload]];

    [[[PWManagerBridge shared] inAppManager] postEvent:defaultApplicationExitEvent
                                        withAttributes:attrs
                                            completion:nil];

    _pendingScreenName = nil;
    _pendingSessionDurationSeconds = 0;
    _pendingExitTimeoutSeconds = 0;
}

- (void)dealloc {
    [self cancelExitBlock];
    [self endBackgroundTask];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#endif
