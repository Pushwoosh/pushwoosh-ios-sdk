//
//  PWIdleDetector.m
//  PushwooshCore
//
//  Created by André Kis on 15.04.26.
//

#if TARGET_OS_IOS

#import "PWIdleDetector.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "PWScreenTrackingManager.h"
#import "PWAppLifecycleTrackingManager.h"
#import "PWUtils.h"
#import "PWInAppManager.h"
#import "PWConfig.h"
#import <PushwooshCore/PWManagerBridge.h>

NSString * const defaultUserIdleEvent = @"PW_UserIdle";

static IMP pw_original_sendEvent_Imp;

@implementation PWIdleDetector {
    NSTimeInterval _idleThreshold;
    BOOL _idleFired;
    BOOL _paused;
    BOOL _keyboardVisible;
    dispatch_block_t _idleBlock;
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
    NSInteger configThreshold = [PWConfig config].idleTimeoutSeconds;
    NSTimeInterval threshold = configThreshold > 0 ? (NSTimeInterval)configThreshold : 0;
#if DEBUG
    NSNumber *debugThreshold = [[NSUserDefaults standardUserDefaults] objectForKey:@"PWDebugIdleThreshold"];
    if (debugThreshold && debugThreshold.doubleValue > 0) {
        threshold = debugThreshold.doubleValue;
    }
#endif
    return [self initWithIdleThreshold:threshold];
}

- (instancetype)initWithIdleThreshold:(NSTimeInterval)threshold {
    if (self = [super init]) {
        _idleThreshold = threshold;
    }
    return self;
}

- (void)startTracking {
    [self swizzleSendEvent];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onKeyboardWillShow)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onKeyboardDidHide)
                                                 name:UIKeyboardDidHideNotification
                                               object:nil];

    [self restartTimer];
}

#pragma mark - Swizzle

static void _replacement_sendEvent(UIApplication *self, SEL _cmd, UIEvent *event) {
    ((void(*)(id, SEL, UIEvent *))pw_original_sendEvent_Imp)(self, _cmd, event);

    if (event.type == UIEventTypeTouches ||
        event.type == UIEventTypePresses ||
        event.type == UIEventTypeHover ||
        event.type == UIEventTypeTransform) {
        [[PWIdleDetector sharedDetector] registerActivity];
    }
}

- (void)swizzleSendEvent {
    static BOOL swizzleDone = NO;
    if (swizzleDone) return;
    swizzleDone = YES;

    Method originalMethod = class_getInstanceMethod([UIApplication class], @selector(sendEvent:));
    pw_original_sendEvent_Imp = method_setImplementation(originalMethod, (IMP)_replacement_sendEvent);
}

#pragma mark - Timer

- (void)restartTimer {
    [self cancelTimer];

    if (_idleFired || _paused || _keyboardVisible || !_defaultIdleTrackingAllowed || _idleThreshold <= 0) return;

    __weak typeof(self) weakSelf = self;
    _idleBlock = dispatch_block_create(0, ^{
        [weakSelf onIdleTimeout];
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_idleThreshold * NSEC_PER_SEC)),
                   dispatch_get_main_queue(),
                   _idleBlock);
}

- (void)cancelTimer {
    if (_idleBlock) {
        dispatch_block_cancel(_idleBlock);
        _idleBlock = nil;
    }
}

- (void)onIdleTimeout {
    if (_idleFired || _paused || _keyboardVisible || !_defaultIdleTrackingAllowed) return;

    _idleFired = YES;
    _idleBlock = nil;
    [self fireIdleEvent];
}

#pragma mark - Activity

- (void)registerActivity {
    if (_keyboardVisible || _idleFired || _paused) return;
    [self restartTimer];
}

- (void)fireIdleEvent {
    NSTimeInterval foregroundMono = [PWAppLifecycleTrackingManager sharedManager].foregroundMonotonicTimestamp;
    NSTimeInterval sessionDuration = foregroundMono > 0
        ? ([NSProcessInfo processInfo].systemUptime - foregroundMono)
        : 0;

    NSMutableDictionary *attrs = [@{
        @"device_type": @1,
        @"application_version": [PWUtils appVersion],
        @"idle_seconds": @((NSInteger)_idleThreshold),
        @"session_duration": @((NSInteger)sessionDuration),
    } mutableCopy];

    NSString *screenName = [PWScreenTrackingManager sharedManager].currentScreenName;
    if (screenName) {
        attrs[@"screen_name"] = screenName;
    }

    [[[PWManagerBridge shared] inAppManager] postEvent:defaultUserIdleEvent
                                        withAttributes:attrs
                                            completion:nil];
}

#pragma mark - Lifecycle

- (void)onResignActive {
    _paused = YES;
    [self cancelTimer];
}

- (void)onBecomeActive {
    _paused = NO;
    _keyboardVisible = NO;
    [self restartTimer];
}

- (void)onDidEnterBackground {
    _idleFired = NO;
    [self cancelTimer];
}

- (void)onKeyboardWillShow {
    _keyboardVisible = YES;
    [self cancelTimer];
}

- (void)onKeyboardDidHide {
    _keyboardVisible = NO;
    [self restartTimer];
}

- (void)dealloc {
    [self cancelTimer];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#endif
