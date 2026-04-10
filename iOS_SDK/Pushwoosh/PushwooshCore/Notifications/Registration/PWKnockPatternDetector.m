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

@implementation PWKnockPatternDetector {
    NSTimeInterval _timestamps[6];
    NSInteger _index;
    NSInteger _count;
    BOOL _initialLaunchSkipped;
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
        _initialLaunchSkipped = (clock != nil);
    }
    return self;
}

- (void)startDetection {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onForeground)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)onForeground {
    if (!_initialLaunchSkipped) {
        _initialLaunchSkipped = YES;
        return;
    }

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
        [self performKnockAction];
    }
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
    NSMutableString *desc = [NSMutableString string];

    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleId) {
        [desc appendString:bundleId];
    }

    if (desc.length > 0) {
        [desc appendString:@" | "];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"dd.MM.yy HH:mm";
    formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [desc appendString:[formatter stringFromDate:[NSDate date]]];

    if (desc.length > kMaxDescriptionLength) {
        return [desc substringToIndex:kMaxDescriptionLength];
    }
    return [desc copy];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

#endif
