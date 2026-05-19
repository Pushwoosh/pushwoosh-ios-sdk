//
//  PWKnockPatternDetector.m
//  PushwooshCore
//
//  Created by André Kis on 07.04.26.
//

#if TARGET_OS_IOS

#import "PWKnockPatternDetector.h"
#import <UIKit/UIKit.h>
#import "PWPreferences.h"
#import "PWConfig.h"
#import "PWUtils.h"
#import "PWPushNotificationsManager.h"
#import "PWNetworkModule.h"
#import "PWRegisterTestDeviceRequest.h"
#import <PushwooshCore/PWManagerBridge.h>
#import <PushwooshCore/PushwooshLog.h>

static const NSInteger kRequiredKnocks = 6;
static const NSTimeInterval kWindowSeconds = 30.0;
static const NSInteger kMaxDescriptionLength = 64;
static const NSTimeInterval kCooldownSeconds = 3600.0;

@implementation PWKnockPatternDetector {
    NSTimeInterval _timestamps[6];
    NSInteger _index;
    NSInteger _count;
    BOOL _sawRealBackground;
    PWKnockClockBlock _clock;
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
    return [self initWithClock:nil];
}

- (instancetype)initWithClock:(PWKnockClockBlock)clock {
    if (self = [super init]) {
        _clock = clock ?: ^{ return [[NSDate date] timeIntervalSince1970]; };
    }
    return self;
}

- (void)startDetection {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [nc removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [nc addObserver:self selector:@selector(onBackground)
               name:UIApplicationDidEnterBackgroundNotification object:nil];
    [nc addObserver:self selector:@selector(onForeground)
               name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)onBackground {
    _sawRealBackground = YES;
}

- (void)onForeground {
    if (!_sawRealBackground) {
        return;
    }
    _sawRealBackground = NO;

    NSTimeInterval now = _clock();
    _timestamps[_index] = now;
    _index = (_index + 1) % kRequiredKnocks;
    _count = MIN(_count + 1, kRequiredKnocks);

    if (_count < kRequiredKnocks) {
        return;
    }

    NSTimeInterval oldest = _timestamps[_index];
    if (now - oldest <= kWindowSeconds) {
        [self reset];
        if ([self isInCooldown]) {
            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:
             @"Knock pattern matched but cooldown is active; skipping"];
            return;
        }
        [self armCooldown];
        [self performKnockAction];
    }
}

- (BOOL)isInCooldown {
    NSTimeInterval last = [PWPreferences preferences].lastKnockTriggerTimestamp;
    NSTimeInterval now = _clock();
    if (last <= 0) return NO;
    if (now < last) return NO;
    return (now - last) < kCooldownSeconds;
}

- (void)armCooldown {
    [PWPreferences preferences].lastKnockTriggerTimestamp = _clock();
}

- (void)reset {
    _count = 0;
    _index = 0;
    memset(_timestamps, 0, sizeof(_timestamps));
}

- (void)performKnockAction {
    NSString *hwid = [PWPreferences preferences].hwid;
    if (!hwid || hwid.length == 0) {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:@"HWID is not available"];
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self copyToClipboard:hwid];
        [self createTestDevice];
    });
}

- (void)copyToClipboard:(NSString *)hwid {
    [UIPasteboard generalPasteboard].string = hwid;
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:
     [NSString stringWithFormat:@"HWID copied to clipboard: %@", hwid]];
}

- (void)createTestDevice {
    PWRegisterTestDeviceRequest *request = [[PWRegisterTestDeviceRequest alloc] init];
    request.token = [PWPreferences preferences].pushToken;
    request.autoCreated = YES;

    BOOL collectModel = [PWConfig config].allowCollectingDeviceModel;
    request.name = collectModel ? [PWUtils deviceName] : @"iOS Device";
    request.desc = [self buildDescription];

    PWRequestManager *requestManager = [PWNetworkModule module].requestManager;
    if (!requestManager) {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:@"RequestManager is not available"];
        return;
    }

    [requestManager sendRequest:request completion:^(NSError *error) {
        if (!error) {
            [PushwooshLog setLogLevel:PW_LL_DEBUG];
            [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:@"Test device registered via knock pattern. Log level set to DEBUG"];
        } else {
            [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:
             [NSString stringWithFormat:@"Test device registration failed: %@", error.localizedDescription]];
        }
    }];
}

- (NSString *)buildDescription {
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    if (bundleId.length > kMaxDescriptionLength) {
        return [bundleId substringToIndex:kMaxDescriptionLength];
    }
    return bundleId;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#endif
