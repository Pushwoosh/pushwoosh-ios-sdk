/*
 *  PWMissingModule.m
 *  PushwooshCore
 *
 *  Created by André Kis on 21.05.26.
 *  Copyright © 2026 Pushwoosh. All rights reserved.
 */

#import "PWMissingModule.h"
#import <PushwooshCore/PushwooshLog.h>
#import <objc/runtime.h>

@implementation PWMissingModule

static const NSUInteger PWMissingModuleMaxLoggedKeys = 256;

static NSMutableSet<NSString *> *_loggedSelectors;
static NSMutableSet<NSString *> *_loggedUnknownSignatures;
static BOOL _loggedSelectorsCapWarned;
static BOOL _loggedUnknownSignaturesCapWarned;
static dispatch_queue_t _loggedSelectorsQueue;

+ (void)initialize {
    if (self == [PWMissingModule class]) {
        _loggedSelectors = [NSMutableSet new];
        _loggedUnknownSignatures = [NSMutableSet new];
        _loggedSelectorsCapWarned = NO;
        _loggedUnknownSignaturesCapWarned = NO;
        _loggedSelectorsQueue = dispatch_queue_create("com.pushwoosh.missingModule.log", DISPATCH_QUEUE_CONCURRENT);
    }
}

+ (BOOL)respondsToSelector:(SEL)aSelector {
    return YES;
}

/// Defensive plugin/bridge code (RN, Flutter, Cordova) commonly guards module
/// calls with `[class conformsToProtocol:@protocol(PW<X>)]`. Without this
/// override the runtime would answer NO for `PWMissingModule` and the plugin
/// would skip the call entirely — even though our `+respondsToSelector:` and
/// `+forwardInvocation:` give a safe no-op for every selector on those
/// protocols. Answer YES for the six module protocols and the three
/// back-channel handler protocols so the contract advertised by the cast
/// `(Class<PW<X>>)PWMissingModule.class` is also reflected via Objective-C
/// protocol introspection.
+ (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    static NSSet<NSString *> *moduleProtocolNames;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        moduleProtocolNames = [NSSet setWithArray:@[
            @"PWLiveActivities",
            @"PWInboxKit",
            @"PWVoIP",
            @"PWForegroundPush",
            @"PWTVoS",
            @"PWKeychain",
            @"PWKeychainPersistentHWIDProvider",
            @"PWVoIPConfigureHandler",
            @"PWTVoSInAppHandler",
        ]];
    });
    if ([moduleProtocolNames containsObject:NSStringFromProtocol(aProtocol)]) {
        return YES;
    }
    return [super conformsToProtocol:aProtocol];
}

+ (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    const char *selectorName = sel_getName(aSelector);
    NSString *name = [NSString stringWithUTF8String:selectorName];

    NSDictionary<NSString *, NSString *> *knownSignatures = [self knownSignatures];
    NSString *typeEncoding = knownSignatures[name];
    if (typeEncoding != nil) {
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:typeEncoding.UTF8String];
        if (signature != nil) {
            return signature;
        }
    }

    if ([name hasPrefix:@"set"] && [name hasSuffix:@":"]) {
        return [NSMethodSignature signatureWithObjCTypes:"v@:@"];
    }

    [self logOnceUnknownSignature:name];
    return [NSMethodSignature signatureWithObjCTypes:"v@:"];
}

+ (void)forwardInvocation:(NSInvocation *)anInvocation {
    SEL selector = anInvocation.selector;
    [self logOnceForSelector:selector];

    [self invokeCompletionWithErrorIfApplicable:anInvocation];

    NSMethodSignature *signature = anInvocation.methodSignature;
    NSUInteger returnLength = signature.methodReturnLength;
    if (returnLength > 0) {
        void *zeroBuffer = calloc(1, returnLength);
        if (zeroBuffer != NULL) {
            [anInvocation setReturnValue:zeroBuffer];
            free(zeroBuffer);
        }
    }
}

/// Invokes the trailing `(NSError *)`-style completion block (if present) with
/// an explicit "module not linked" error. The six optional-module protocols
/// uniformly use `(NSError * _Nullable) -> Void` for completion handlers, so a
/// fixed block signature is safe. Both forms emitted by Swift's Obj-C bridge
/// are matched: `...completion:` (when `completion` is a non-first argument
/// label) and `...WithCompletion:` (when it is the only / first label).
/// Selectors that do not match either suffix are left alone — a trailing block
/// on such a selector belongs to a different contract (e.g.
/// `setDidTapForegroundPush:` stores a closure rather than calling it) and
/// must not be invoked here.
+ (void)invokeCompletionWithErrorIfApplicable:(NSInvocation *)anInvocation {
    NSString *selectorName = NSStringFromSelector(anInvocation.selector);
    if (![selectorName hasSuffix:@"completion:"] && ![selectorName hasSuffix:@"WithCompletion:"]) {
        return;
    }

    NSMethodSignature *signature = anInvocation.methodSignature;
    NSUInteger numberOfArguments = signature.numberOfArguments;
    if (numberOfArguments == 0) {
        return;
    }

    NSUInteger lastIndex = numberOfArguments - 1;
    const char *encoding = [signature getArgumentTypeAtIndex:lastIndex];
    if (encoding == NULL || strcmp(encoding, "@?") != 0) {
        return;
    }

    __unsafe_unretained void (^block)(NSError *) = nil;
    [anInvocation getArgument:&block atIndex:lastIndex];
    if (block == nil) {
        return;
    }

    NSError *error = [NSError errorWithDomain:@"com.pushwoosh.module"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Optional Pushwoosh module not linked."}];
    block(error);
}

/// Hand-curated signatures for selectors declared on the six optional-module
/// protocols (PWKeychain / PWInboxKit / PWVoIP / PWLiveActivities /
/// PWForegroundPush / PWTVoS) plus the back-channel handler protocols
/// (PWKeychainPersistentHWIDProvider / PWTVoSInAppHandler /
/// PWVoIPConfigureHandler).
///
/// The `set...:` fallback in `methodSignatureForSelector:` is a heuristic
/// that assumes an object (`@`) argument — add an explicit entry below for
/// any setter whose argument type is a primitive (BOOL, integer, float,
/// double, etc.). Likewise, any selector with a non-void return MUST be
/// listed here, otherwise `forwardInvocation:` zero-fills only the bytes
/// the default `v@:` signature reports (zero) and the caller reads garbage
/// from the return register.
///
/// Type encodings used:
///   v = void, B = BOOL, q = NSInteger / TimeInterval-via-Int, d = double,
///   @ = id, : = SEL, @? = block.
+ (NSDictionary<NSString *, NSString *> *)knownSignatures {
    static NSDictionary<NSString *, NSString *> *signatures;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        signatures = @{
            @"keychain":                                        @"#@:",
            @"isEnabled":                                       @"B@:",
            @"currentEnvironment":                              @"q@:",
            @"getPersistentHWID":                               @"@@:",
            @"clearPersistentHWID":                             @"v@:",

            @"isPersistentHWIDEnabled":                         @"B@:",
            @"persistentHWID":                                  @"@@:",

            @"inboxKit":                                        @"#@:",

            @"voip":                                            @"#@:",
            @"initializeVoIP:ringtoneSound:handleTypes:":       @"v@:B@q",
            @"setVoIPToken:":                                   @"v@:@",
            @"setIncomingCallTimeout:":                         @"v@:d",
            @"delegate":                                        @"@@:",

            @"configureVoIP":                                   @"v@:",

            @"liveActivities":                                  @"#@:",
            @"sendPushToStartLiveActivityWithToken:":           @"v@:@",
            @"sendPushToStartLiveActivityWithToken:completion:": @"v@:@@?",
            @"startLiveActivityWithToken:activityId:":          @"v@:@@",
            @"startLiveActivityWithToken:activityId:completion:": @"v@:@@@?",
            @"stopLiveActivity":                                @"v@:",
            @"stopLiveActivityWithCompletion:":                 @"v@:@?",
            @"stopLiveActivityWithActivityId:":                 @"v@:@",
            @"stopLiveActivityWithActivityId:completion:":      @"v@:@@?",
            @"defaultSetup":                                    @"v@:",
            @"defaultStart:attributes:content:":                @"v@:@@@",
            @"defaultStart:attributes:content:completion:":     @"v@:@@@@?",

            @"foregroundPush":                                  @"#@:",
            @"gradientColors":                                  @"@@:",
            @"backgroundColor":                                 @"@@:",
            @"usePushAnimation":                                @"B@:",
            @"titlePushColor":                                  @"@@:",
            @"titlePushFont":                                   @"@@:",
            @"messagePushFont":                                 @"@@:",
            @"messagePushColor":                                @"@@:",
            @"useLiquidView":                                   @"B@:",
            @"didTapForegroundPush":                            @"@?@:",
            @"setUsePushAnimation:":                            @"v@:B",
            @"setUseLiquidView:":                               @"v@:B",
            @"setDidTapForegroundPush:":                        @"v@:@?",
            @"foregroundNotificationWithStyle:duration:vibration:disappearedPushAnimation:": @"v@:qqqq",
            @"showForegroundPushWithUserInfo:":                 @"v@:@",

            @"tvos":                                            @"#@:",
            @"setAppCode:":                                     @"v@:@",
            @"registerForTvPushNotifications":                  @"v@:",
            @"registerForTvPushNotificationsWithToken:completion:": @"v@:@@?",
            @"unregisterForTvPushNotificationsWithCompletion:": @"v@:@?",
            @"handleTvPushToken:":                              @"v@:@",
            @"handleTvPushRegistrationFailure:":                @"v@:@",
            @"handleTvPushReceivedWithUserInfo:completionHandler:": @"v@:@@?",
            @"handleTVOSPushWithUserInfo:":                     @"B@:@",
            @"configureRichMediaWithPosition:presentAnimation:dismissAnimation:": @"v@:qqq",
            @"configureCloseButton:":                           @"v@:B",
            @"setRichMediaGetTagsHandler:":                     @"v@:@?",

            @"handleInAppResource:":                            @"v@:@",
        };
    });
    return signatures;
}

+ (void)_resetLogStateForTesting {
    dispatch_barrier_sync(_loggedSelectorsQueue, ^{
        [_loggedSelectors removeAllObjects];
        [_loggedUnknownSignatures removeAllObjects];
        _loggedSelectorsCapWarned = NO;
        _loggedUnknownSignaturesCapWarned = NO;
    });
}

+ (void)logOnceForSelector:(SEL)selector {
    NSString *key = NSStringFromSelector(selector);
    __block BOOL shouldLog = NO;
    __block BOOL shouldWarnCap = NO;
    dispatch_barrier_sync(_loggedSelectorsQueue, ^{
        if (_loggedSelectors.count >= PWMissingModuleMaxLoggedKeys) {
            if (!_loggedSelectorsCapWarned) {
                _loggedSelectorsCapWarned = YES;
                shouldWarnCap = YES;
            }
            return;
        }
        if (![_loggedSelectors containsObject:key]) {
            [_loggedSelectors addObject:key];
            shouldLog = YES;
        }
    });
    if (shouldWarnCap) {
        NSString *capMessage = [NSString stringWithFormat:@"PWMissingModule: selector log cap reached (%lu unique selectors). Further 'module not linked' logs are suppressed to bound memory. Likely a plugin wrapper bridging a high-cardinality selector set against an unlinked module.", (unsigned long)PWMissingModuleMaxLoggedKeys];
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:capMessage];
    }
    if (!shouldLog) {
        return;
    }

    NSString *message = [NSString stringWithFormat:@"Optional Pushwoosh module not linked. Selector '%@' forwarded as no-op. Link the matching Pushwoosh<X> framework.", key];
    [PushwooshLog pushwooshLog:PW_LL_INFO className:self message:message];
}

+ (void)logOnceUnknownSignature:(NSString *)selectorName {
    __block BOOL shouldLog = NO;
    __block BOOL shouldWarnCap = NO;
    dispatch_barrier_sync(_loggedSelectorsQueue, ^{
        if (_loggedUnknownSignatures.count >= PWMissingModuleMaxLoggedKeys) {
            if (!_loggedUnknownSignaturesCapWarned) {
                _loggedUnknownSignaturesCapWarned = YES;
                shouldWarnCap = YES;
            }
            return;
        }
        if (![_loggedUnknownSignatures containsObject:selectorName]) {
            [_loggedUnknownSignatures addObject:selectorName];
            shouldLog = YES;
        }
    });
    if (shouldWarnCap) {
        NSString *capMessage = [NSString stringWithFormat:@"PWMissingModule: unknown-signature log cap reached (%lu unique selectors). Further drift warnings are suppressed to bound memory.", (unsigned long)PWMissingModuleMaxLoggedKeys];
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:capMessage];
    }
    if (!shouldLog) {
        return;
    }

    NSString *message = [NSString stringWithFormat:@"PWMissingModule: selector '%@' not in knownSignatures, defaulting to 'v@:'. If this is a back-channel protocol method with a non-void return, add an explicit signature entry.", selectorName];
    [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:message];
}

@end
