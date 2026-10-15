//  PWFeatureFlagsManager.m
//  Created by André Kis

#import "PWFeatureFlagsManager.h"

#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

#import "PWConfig.h"
#import "PWFeatureFlag+Internal.h"
#import "PWGetFeatureFlagsRequest.h"
#import "PWInAppManager.h"
#import "PWManagerBridge.h"
#import "PWNetworkModule.h"
#import "PWPreferences.h"
#import "PWSdkStateProvider.h"
#import "PushwooshLog.h"

typedef void (^PWFeatureFlagsCompletion)(NSError *error);

static NSString *const kPWFeatureFlagsCacheKey = @"PWFeatureFlagsCache";
static NSString *const kPWCacheFlagsKey = @"flags";
static NSString *const kPWCacheEtagKey = @"etag";
static NSString *const kPWCacheFetchedAtKey = @"fetchedAt";
static NSString *const kPWCacheUserIdKey = @"userId";
static NSString *const kPWCacheLastRequestAtKey = @"lastRequestAt";
static NSString *const kPWCacheAppCodeKey = @"appCode";
static NSString *const kPWCacheRegisteredKey = @"registered";
static NSString *const kPWFeatureFlagImpressionEvent = @"PW_FeatureFlagImpression";
static NSString *const kPWFeatureFlagsExtensionSkippedMessage = @"Feature flags refresh skipped: not available in app extensions";
static NSString *const kPWFeatureFlagsReverseProxySkippedMessage = @"Feature flags refresh skipped: reverse proxy URL does not end with json/1.3/";

static NSTimeInterval const kPWFeatureFlagsMaxCacheAge = 24 * 60 * 60;
static NSTimeInterval const kPWFeatureFlagsThrottle = 5 * 60;
static NSTimeInterval const kPWFeatureFlagsSessionGap = 30 * 60;
static NSTimeInterval const kPWFeatureFlagsPeriodicRefresh = 60 * 60;

@interface PWFeatureFlagsManager ()

@property (nonatomic, copy) NSTimeInterval (^clock)(void);
@property (nonatomic, copy) void (^scheduler)(NSTimeInterval delay, dispatch_block_t fire);
@property (nonatomic) BOOL inAppExtension;
@property (nonatomic, copy) BOOL (^applicationActive)(void);

@end

@implementation PWFeatureFlagsManager {
    NSDictionary<NSString *, PWFeatureFlag *> *_flags;
    NSString *_etag;
    NSTimeInterval _fetchedAt;
    NSString *_boundUserId;
    NSString *_boundAppCode;
    BOOL _persisted;
    NSTimeInterval _lastRequestAt;
    NSString *_registeredAppCode;
    BOOL _inFlight;
    NSMutableArray<PWFeatureFlagsCompletion> *_waiting;
    BOOL _followUpQueued;
    NSMutableArray<PWFeatureFlagsCompletion> *_followUpWaiting;
    BOOL _lastSentUnregistered;
    NSUInteger _cacheGeneration;
    BOOL _started;
    BOOL _sessionStarted;
    NSTimeInterval _backgroundedAt;
    NSUInteger _timerGeneration;
    NSHashTable<id<PWFeatureFlagsUpdateListener>> *_listeners;
    NSMutableSet<NSArray *> *_sentImpressions;
    NSMutableSet<NSArray *> *_impressionsInFlight;
    NSUInteger _impressionSession;
}

+ (instancetype)sharedManager {
    static PWFeatureFlagsManager *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [PWFeatureFlagsManager new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self installDefaultSeams];
        _waiting = [NSMutableArray new];
        _followUpWaiting = [NSMutableArray new];
        _backgroundedAt = -1;
        _listeners = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality capacity:0];
        _sentImpressions = [NSMutableSet new];
        _impressionsInFlight = [NSMutableSet new];
        [self resetCacheInMemory];
        [self loadCache];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(activeApplicationChanged:)
                                                     name:kPWActiveApplicationChangedNotification
                                                   object:nil];
    }
    return self;
}

- (void)installDefaultSeams {
    _clock = ^NSTimeInterval {
        return [[NSDate date] timeIntervalSince1970];
    };
    _scheduler = ^(NSTimeInterval delay, dispatch_block_t fire) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), fire);
    };
    _inAppExtension = [[NSBundle mainBundle].bundlePath hasSuffix:@".appex"];
    _applicationActive = ^BOOL {
        return [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
    };
}

#pragma mark - Triggers

- (void)start {
    [self startObservingApplication];
}

- (void)startAfterLaunch {
    if (![self startObservingApplication]) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.applicationActive()) {
            [self applicationDidBecomeActive];
        }
    });
}

- (BOOL)startObservingApplication {
    if (_inAppExtension) {
        return NO;
    }
    @synchronized (self) {
        if (_started) {
            return NO;
        }
        _started = YES;
    }
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [center addObserver:self selector:@selector(applicationDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    return YES;
}

- (void)applicationDidBecomeActive {
    BOOL newSession;
    @synchronized (self) {
        NSTimeInterval now = _clock();
        BOOL renewed = _sessionStarted && _backgroundedAt >= 0 && now - _backgroundedAt >= kPWFeatureFlagsSessionGap;
        newSession = !_sessionStarted || renewed;
        _sessionStarted = YES;
        _backgroundedAt = -1;
        if (renewed) {
            [self resetImpressions];
        }
    }
    if (newSession) {
        [self refreshWithCompletion:nil bypassThrottle:NO];
    }
    [self schedulePeriodicRefreshAfter:[self untilPeriodicRefreshDue]];
}

- (void)applicationDidEnterBackground {
    @synchronized (self) {
        _backgroundedAt = _clock();
        _timerGeneration++;
    }
}

- (NSTimeInterval)untilPeriodicRefreshDue {
    NSTimeInterval sinceLast;
    @synchronized (self) {
        sinceLast = _clock() - _lastRequestAt;
    }
    if (sinceLast < 0 || sinceLast >= kPWFeatureFlagsPeriodicRefresh) {
        return 0;
    }
    return kPWFeatureFlagsPeriodicRefresh - sinceLast;
}

- (void)schedulePeriodicRefreshAfter:(NSTimeInterval)delay {
    NSUInteger generation;
    @synchronized (self) {
        generation = ++_timerGeneration;
    }
    __weak typeof(self) wSelf = self;
    _scheduler(delay, ^{
        [wSelf periodicRefreshFired:generation];
    });
}

- (void)periodicRefreshFired:(NSUInteger)generation {
    @synchronized (self) {
        if (generation != _timerGeneration) {
            return;
        }
    }
    NSTimeInterval due = [self untilPeriodicRefreshDue];
    if (due > 0) {
        [self schedulePeriodicRefreshAfter:due];
        return;
    }
    [self refreshWithCompletion:nil bypassThrottle:NO];
    [self schedulePeriodicRefreshAfter:kPWFeatureFlagsPeriodicRefresh];
}

- (void)deviceRegistered {
    NSString *appCode = [self currentAppCode];
    BOOL refresh;
    @synchronized (self) {
        _registeredAppCode = appCode;
        [self updateStoredCache:@{ kPWCacheRegisteredKey: appCode }];
        refresh = _lastSentUnregistered;
        _lastSentUnregistered = NO;
    }
    if (refresh) {
        [self refreshWithCompletion:nil bypassThrottle:YES];
    }
}

- (void)userIdUpdated {
    if (_inAppExtension) {
        return;
    }
    NSString *userId = [self effectiveUserId];
    @synchronized (self) {
        if ([_boundUserId isEqualToString:userId]) {
            _etag = @"";
            _cacheGeneration++;
            [self updateStoredCache:@{ kPWCacheEtagKey: @"" }];
            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"User confirmed, feature flags revalidated without etag"];
        } else {
            [self clearCacheForChangedUser];
        }
    }
    [self refreshWithCompletion:nil bypassThrottle:YES];
}

- (void)userIdUpdateFailed {
    if (_inAppExtension) {
        return;
    }
    NSString *userId = [self effectiveUserId];
    @synchronized (self) {
        if (!_boundUserId || [_boundUserId isEqualToString:userId]) {
            return;
        }
        [self clearCacheForChangedUser];
    }
    [self refreshWithCompletion:nil bypassThrottle:YES];
}

- (void)clearCacheForChangedUser {
    [self clearCacheKeepingRegistration:YES];
    [self resetImpressions];
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"User changed, feature flags cache cleared"];
}

#pragma mark - Listeners

- (void)addUpdateListener:(id<PWFeatureFlagsUpdateListener>)listener {
    if (!listener) {
        return;
    }
    @synchronized (self) {
        [_listeners addObject:listener];
    }
}

- (void)removeUpdateListener:(id<PWFeatureFlagsUpdateListener>)listener {
    if (!listener) {
        return;
    }
    @synchronized (self) {
        [_listeners removeObject:listener];
    }
}

- (void)notifyListeners {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSArray<id<PWFeatureFlagsUpdateListener>> *listeners;
        @synchronized (self) {
            listeners = self->_listeners.allObjects;
        }
        for (id<PWFeatureFlagsUpdateListener> listener in listeners) {
            [listener featureFlagsDidUpdate];
        }
    });
}

- (NSDictionary<NSString *, PWFeatureFlag *> *)visibleFlagsForUserId:(NSString *)userId appCode:(NSString *)appCode {
    return [self hasValidCacheForUserId:userId appCode:appCode] ? _flags : @{};
}

- (BOOL)flags:(NSDictionary<NSString *, PWFeatureFlag *> *)flags lookLike:(NSDictionary<NSString *, PWFeatureFlag *> *)otherFlags {
    if (flags.count != otherFlags.count) {
        return NO;
    }
    for (NSString *key in flags) {
        PWFeatureFlag *other = otherFlags[key];
        if (!other || ![flags[key] hasSameValueAsFlag:other]) {
            return NO;
        }
    }
    return YES;
}

#pragma mark - Impressions

- (void)logImpression:(NSString *)key {
    [[PWSdkStateProvider sharedInstance] executeOrQueue:^{
        [self postImpressionOfFlagForKey:key];
    }];
}

- (void)postImpressionOfFlagForKey:(NSString *)key {
    PWFeatureFlag *flag = [self flagForKey:key];
    if (!flag) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Feature flag impression skipped, no cached flag: %@", key]];
        return;
    }
    PWInAppManager *inAppManager = [PWManagerBridge shared].inAppManager;
    if (!inAppManager) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Feature flag impression skipped, SDK is not initialized: %@", key]];
        return;
    }
    NSArray *impression = @[ key, flag.ruleId, flag.isEnabled ? @YES : @NO ];
    NSUInteger session;
    @synchronized (self) {
        if ([_sentImpressions containsObject:impression] || [_impressionsInFlight containsObject:impression]) {
            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Feature flag impression already logged this session: %@", key]];
            return;
        }
        [_impressionsInFlight addObject:impression];
        session = _impressionSession;
    }
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Feature flag impression posted: %@", key]];
    NSDictionary *attributes = @{ @"flag_key": key, @"rule_id": flag.ruleId, @"enabled": impression[2] };
    [inAppManager postEvent:kPWFeatureFlagImpressionEvent withAttributes:attributes completion:^(NSError *error) {
        [self finishImpression:impression session:session succeeded:error == nil];
    }];
}

- (void)finishImpression:(NSArray *)impression session:(NSUInteger)session succeeded:(BOOL)succeeded {
    @synchronized (self) {
        if (session != _impressionSession) {
            return;
        }
        [_impressionsInFlight removeObject:impression];
        if (succeeded) {
            [_sentImpressions addObject:impression];
        }
    }
    if (!succeeded) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Feature flag impression failed, next call retries: %@", impression.firstObject]];
    }
}

- (void)resetImpressions {
    [_sentImpressions removeAllObjects];
    [_impressionsInFlight removeAllObjects];
    _impressionSession++;
}

#pragma mark - Application

- (void)activeApplicationChanged:(NSNotification *)notification {
    NSNumber *appCodeChanged = notification.userInfo[kPWActiveApplicationChangedAppCodeChangedKey];
    if ([appCodeChanged isKindOfClass:[NSNumber class]] && !appCodeChanged.boolValue) {
        return;
    }
    @synchronized (self) {
        [self clearCacheKeepingRegistration:NO];
        [self resetImpressions];
    }
    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"Active application changed, feature flags cache cleared"];
}

#pragma mark - Reading

- (PWFeatureFlag *)flagForKey:(NSString *)key {
    NSString *userId = [self effectiveUserId];
    NSString *appCode = [self currentAppCode];
    @synchronized (self) {
        return [self hasValidCacheForUserId:userId appCode:appCode] ? _flags[key] : nil;
    }
}

- (BOOL)isBoundToUserId:(NSString *)userId appCode:(NSString *)appCode {
    return [_boundUserId isEqualToString:userId] && [_boundAppCode isEqualToString:appCode];
}

- (BOOL)hasValidCacheForUserId:(NSString *)userId appCode:(NSString *)appCode {
    if (![self isBoundToUserId:userId appCode:appCode]) {
        return NO;
    }
    NSTimeInterval age = _clock() - _fetchedAt;
    return age >= 0 && age <= kPWFeatureFlagsMaxCacheAge;
}

- (NSString *)currentAppCode {
    return [PWPreferences preferences].appCode ?: @"";
}

- (NSString *)effectiveUserId {
    NSString *userId = [PWPreferences preferences].userId;
    if (userId.length > 0) {
        return userId;
    }
    return [PWPreferences preferences].hwid ?: @"";
}

#pragma mark - Refresh

- (void)refreshWithCompletion:(PWFeatureFlagsCompletion)completion {
    [self refreshWithCompletion:completion bypassThrottle:NO];
}

- (void)refreshWithCompletion:(PWFeatureFlagsCompletion)completion bypassThrottle:(BOOL)bypassThrottle {
    if (_inAppExtension) {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:kPWFeatureFlagsExtensionSkippedMessage];
        [self deliverError:[self errorWithStatus:0 message:kPWFeatureFlagsExtensionSkippedMessage] to:completion];
        return;
    }
    if ([PWSdkStateProvider sharedInstance].currentState == PWSdkStateError) {
        [self deliverError:[self errorWithStatus:0 message:@"Feature flags refresh skipped: SDK initialization failed"] to:completion];
        return;
    }

    [[PWSdkStateProvider sharedInstance] executeOrQueue:^{
        [self startOrJoinWithCompletion:completion bypassThrottle:bypassThrottle];
    }];
}

- (void)startOrJoinWithCompletion:(PWFeatureFlagsCompletion)completion bypassThrottle:(BOOL)bypassThrottle {
    NSString *userId = [self effectiveUserId];
    NSString *appCode = [self currentAppCode];
    dispatch_block_t send;

    @synchronized (self) {
        if (_inFlight) {
            if (bypassThrottle) {
                _followUpQueued = YES;
                [self addCompletion:completion to:_followUpWaiting];
            } else {
                [self addCompletion:completion to:_waiting];
            }
            return;
        }
        if (!bypassThrottle && [self isThrottledForUserId:userId appCode:appCode]) {
            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"Feature flags refresh throttled"];
            [self deliverError:nil to:completion];
            return;
        }
        [self addCompletion:completion to:_waiting];
        send = [self prepareSendForUserId:userId appCode:appCode];
    }

    if (send) {
        send();
    }
}

- (BOOL)isThrottledForUserId:(NSString *)userId appCode:(NSString *)appCode {
    if (![self hasValidCacheForUserId:userId appCode:appCode]) {
        return NO;
    }
    NSTimeInterval sinceLast = _clock() - _lastRequestAt;
    if (sinceLast < 0 || sinceLast >= kPWFeatureFlagsThrottle) {
        return NO;
    }
    return ![PWConfig config].featureFlagsThrottleDisabled;
}

- (dispatch_block_t)prepareSendForUserId:(NSString *)userId appCode:(NSString *)appCode {
    PWRequestManager *requestManager = [PWNetworkModule module].requestManager;
    BOOL viaReverseProxy = [requestManager isUsingReverseProxy];
    if (viaReverseProxy && ![PWGetFeatureFlagsRequest endpointForBaseUrl:[requestManager baseUrl] viaReverseProxy:YES appCode:nil]) {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:kPWFeatureFlagsReverseProxySkippedMessage];
        [self finishWaitingWithError:[self errorWithStatus:0 message:kPWFeatureFlagsReverseProxySkippedMessage]];
        return nil;
    }

    _inFlight = YES;
    NSUInteger generation = _cacheGeneration;
    PWGetFeatureFlagsRequest *request = [PWGetFeatureFlagsRequest new];
    request.etag = _persisted && [self isBoundToUserId:userId appCode:appCode] ? _etag : @"";
    _lastSentUnregistered = ![_registeredAppCode isEqualToString:appCode];
    _lastRequestAt = _clock();
    [self updateStoredCache:@{ kPWCacheLastRequestAtKey: @(_lastRequestAt) }];

    return ^{
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:request.etag.length > 0 ? @"Feature flags refresh sent with etag" : @"Feature flags refresh sent"];
        [requestManager sendRequest:request completion:^(NSError *error) {
            [self handleResponseOfRequest:request sentForUserId:userId generation:generation error:error];
        }];
    };
}

- (void)addCompletion:(PWFeatureFlagsCompletion)completion to:(NSMutableArray<PWFeatureFlagsCompletion> *)completions {
    if (completion) {
        [completions addObject:[completion copy]];
    }
}

- (void)handleResponseOfRequest:(PWGetFeatureFlagsRequest *)request sentForUserId:(NSString *)requestUserId generation:(NSUInteger)generation error:(NSError *)error {
    PWFeatureFlagsResponse *response = request.response;
    NSError *outcome = nil;
    if (error || !response) {
        NSInteger status = error ? request.httpCode : 200;
        if (status == 200) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"Feature flags response could not be used"];
        } else {
            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Feature flags refresh failed, HTTP %ld", (long)status]];
        }
        outcome = [self errorWithStatus:status message:error.localizedDescription ?: @"Feature flags response could not be used"];
    }

    NSString *currentUserId = [self effectiveUserId];
    NSString *currentAppCode = [self currentAppCode];
    dispatch_block_t followUp = nil;
    BOOL changed = NO;
    @synchronized (self) {
        _inFlight = NO;
        if (!outcome) {
            if (generation != _cacheGeneration) {
                [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"Feature flags cache cleared while in flight, response dropped"];
            } else if ([requestUserId isEqualToString:currentUserId]) {
                NSDictionary<NSString *, PWFeatureFlag *> *before = [self visibleFlagsForUserId:currentUserId appCode:currentAppCode];
                [self applyResponse:response userId:requestUserId appCode:request.appCode];
                changed = ![self flags:before lookLike:[self visibleFlagsForUserId:currentUserId appCode:currentAppCode]];
            } else {
                [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"User changed while feature flags were in flight, response dropped"];
            }
        }
        [self finishWaitingWithError:outcome];
        if (_followUpQueued) {
            _followUpQueued = NO;
            [_waiting addObjectsFromArray:_followUpWaiting];
            [_followUpWaiting removeAllObjects];
            followUp = [self prepareSendForUserId:currentUserId appCode:currentAppCode];
        }
    }

    if (changed) {
        [self notifyListeners];
    }
    if (followUp) {
        followUp();
    }
}

- (void)applyResponse:(PWFeatureFlagsResponse *)response userId:(NSString *)userId appCode:(NSString *)appCode {
    NSTimeInterval now = _clock();
    if (response.notModified) {
        if (_persisted && [self isBoundToUserId:userId appCode:appCode]) {
            _fetchedAt = now;
            [self updateStoredCache:@{ kPWCacheFetchedAtKey: @(now) }];
        }
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"Feature flags not modified"];
    } else if (response.partial) {
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:@"Feature flags response is partial, not cached"];
        if (!_persisted || ![self hasValidCacheForUserId:userId appCode:appCode]) {
            [self setFlags:response.flags etag:@"" fetchedAt:now userId:userId appCode:appCode persisted:NO];
        }
    } else {
        [self setFlags:response.flags etag:response.etag fetchedAt:now userId:userId appCode:appCode persisted:YES];
        [self updateStoredCache:@{ kPWCacheFlagsKey: response.flagsJSON,
                                   kPWCacheEtagKey: response.etag,
                                   kPWCacheFetchedAtKey: @(now),
                                   kPWCacheUserIdKey: userId,
                                   kPWCacheAppCodeKey: appCode }];
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Feature flags updated: %lu flags", (unsigned long)response.flags.count]];
    }
}

- (void)finishWaitingWithError:(NSError *)error {
    NSArray<PWFeatureFlagsCompletion> *done = [_waiting copy];
    [_waiting removeAllObjects];
    for (PWFeatureFlagsCompletion completion in done) {
        [self deliverError:error to:completion];
    }
}

- (void)deliverError:(NSError *)error to:(PWFeatureFlagsCompletion)completion {
    if (!completion) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(error);
    });
}

- (NSError *)errorWithStatus:(NSInteger)status message:(NSString *)message {
    return [NSError errorWithDomain:PWFeatureFlagsErrorDomain code:status userInfo:@{ NSLocalizedDescriptionKey: message }];
}

#pragma mark - Cache

- (void)setFlags:(NSDictionary<NSString *, PWFeatureFlag *> *)flags etag:(NSString *)etag fetchedAt:(NSTimeInterval)fetchedAt userId:(NSString *)userId appCode:(NSString *)appCode persisted:(BOOL)persisted {
    _flags = flags;
    _etag = etag;
    _fetchedAt = fetchedAt;
    _boundUserId = userId;
    _boundAppCode = appCode;
    _persisted = persisted;
}

- (void)resetCacheInMemory {
    [self setFlags:@{} etag:@"" fetchedAt:0 userId:nil appCode:nil persisted:NO];
}

- (void)clearCacheKeepingRegistration:(BOOL)keepRegistration {
    [self resetCacheInMemory];
    _cacheGeneration++;
    if (!keepRegistration) {
        _registeredAppCode = nil;
    }
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kPWFeatureFlagsCacheKey];
    NSMutableDictionary *kept = [NSMutableDictionary new];
    kept[kPWCacheLastRequestAtKey] = stored[kPWCacheLastRequestAtKey];
    if (keepRegistration) {
        kept[kPWCacheRegisteredKey] = stored[kPWCacheRegisteredKey];
    }
    [[NSUserDefaults standardUserDefaults] setObject:kept forKey:kPWFeatureFlagsCacheKey];
}

- (void)loadCache {
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kPWFeatureFlagsCacheKey];
    NSNumber *lastRequestAt = stored[kPWCacheLastRequestAtKey];
    _lastRequestAt = [lastRequestAt isKindOfClass:[NSNumber class]] ? lastRequestAt.doubleValue : 0;
    NSString *registeredAppCode = stored[kPWCacheRegisteredKey];
    _registeredAppCode = [registeredAppCode isKindOfClass:[NSString class]] ? registeredAppCode : nil;

    NSString *flagsJSON = stored[kPWCacheFlagsKey];
    NSString *userId = stored[kPWCacheUserIdKey];
    NSString *appCode = stored[kPWCacheAppCodeKey];
    if (![flagsJSON isKindOfClass:[NSString class]] || flagsJSON.length == 0 || ![userId isKindOfClass:[NSString class]] || userId.length == 0 || ![appCode isKindOfClass:[NSString class]]) {
        return;
    }

    id json = [NSJSONSerialization JSONObjectWithData:[flagsJSON dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    NSDictionary<NSString *, PWFeatureFlag *> *flags = json ? [PWFeatureFlag flagsWithJSONObject:json] : nil;
    if (!flags) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"Cached feature flags are unreadable, dropping them"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPWFeatureFlagsCacheKey];
        return;
    }

    NSString *etag = stored[kPWCacheEtagKey];
    NSNumber *fetchedAt = stored[kPWCacheFetchedAtKey];
    [self setFlags:flags
              etag:[etag isKindOfClass:[NSString class]] ? etag : @""
         fetchedAt:[fetchedAt isKindOfClass:[NSNumber class]] ? fetchedAt.doubleValue : 0
            userId:userId
           appCode:appCode
         persisted:YES];
}

- (void)updateStoredCache:(NSDictionary *)values {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *stored = [[defaults dictionaryForKey:kPWFeatureFlagsCacheKey] mutableCopy] ?: [NSMutableDictionary new];
    [stored addEntriesFromDictionary:values];
    [defaults setObject:stored forKey:kPWFeatureFlagsCacheKey];
}

#pragma mark - Testing

- (void)resetForTesting {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    @synchronized (self) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kPWFeatureFlagsCacheKey];
        [self resetCacheInMemory];
        [self installDefaultSeams];
        _lastRequestAt = 0;
        _registeredAppCode = nil;
        _inFlight = NO;
        [_waiting removeAllObjects];
        _followUpQueued = NO;
        [_followUpWaiting removeAllObjects];
        _lastSentUnregistered = NO;
        _cacheGeneration++;
        _started = NO;
        _sessionStarted = NO;
        _backgroundedAt = -1;
        _timerGeneration++;
        [_listeners removeAllObjects];
        [self resetImpressions];
    }
}

@end

#endif
