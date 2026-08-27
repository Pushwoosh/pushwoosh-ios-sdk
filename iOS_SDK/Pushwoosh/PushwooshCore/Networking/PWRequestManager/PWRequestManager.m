//
//  PWRequestManager.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRequestManager.h"
#import "PWPushRuntime.h"
#import "PWSetTagsRequest.h"
#import "Constants.h"
#import "PWConfig.h"
#import "PWCombinedSetTagsRequest.h"
#import "PWPreferences.h"
#import "PWUtils.h"
#import <PushwooshCore/PWManagerBridge.h>
#import "PWServerCommunicationManager.h"
#import "PushwooshLog.h"
#import "PWSdkStateProvider.h"
#import "PWRetryQueue.h"
#import "PWRetryPolicy.h"
#import "PWRetryEntry.h"
#import "PWRetryQueueStorage.h"
#import "PWReplayRequest.h"
#import "PWRequest+Internal.h"

#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV
#import "PWReachability.h"
#endif

@protocol PWGRPCTransport <NSObject>
+ (BOOL)isAvailable;
+ (void)sendRequest:(PWRequest *)request completion:(void (^)(NSDictionary *, NSError *))completion;
+ (NSString *)transportName;
@end

@interface PWRequestManager () <PWRetryTransport>

@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSURLSession *retrySession;

@property (nonatomic, strong) NSObject *sendTagsLock;
@property (nonatomic, strong) PWCombinedSetTagsRequest *combinedRequest;
@property (nonatomic, strong) NSMutableArray *sendTagsCompletions;
@property (nonatomic, copy) NSString *reverseProxyUrl;
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *customHeaders;
@property (nonatomic, strong) NSMutableSet<NSString *> *warnedQueueReasons;
@property (nonatomic, strong) NSMutableSet<NSString *> *warnedRotationHosts;

// gRPC transport class (dynamically loaded)
@property (nonatomic, strong) Class grpcTransportClass;

@property (nonatomic, strong) PWRetryQueue *retryQueue;
@property (nonatomic, strong) PWRetryPolicy *retryPolicy;
#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV
@property (nonatomic, strong) PWReachability *reachability;
#endif

@end

@implementation PWRequestManager

static NSString *const kPWSharedReverseProxyURLKey = @"PWReverseProxyURL";
static NSString *const kPWSharedCustomHeadersKey = @"PWCustomHeaders";

- (instancetype)init {
	if (self = [super init]) {
		NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
		_session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:[NSOperationQueue mainQueue]];

		NSURLSessionConfiguration *retryConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
		retryConfiguration.timeoutIntervalForRequest = 80;
		retryConfiguration.timeoutIntervalForResource = 80;
		_retrySession = [NSURLSession sessionWithConfiguration:retryConfiguration delegate:nil delegateQueue:nil];
		_sendTagsLock = [NSObject new];
		_sendTagsCompletions = [NSMutableArray new];
		_customHeaders = @{};
		_warnedQueueReasons = [NSMutableSet new];
		_warnedRotationHosts = [NSMutableSet new];

        _grpcTransportClass = NSClassFromString(@"PushwooshGRPC.PushwooshGRPCImplementation");

        [self seedAppCodeFromInfoPlistIfNeeded];

        if ([PWConfig config].allowReverseProxy) {
            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"Pushwoosh_ALLOW_REVERSE_PROXY is enabled. All requests will be queued until setReverseProxy() is called."];
        } else {
            [self clearSharedReverseProxySettings];
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onAppCodeUpdatedNotification:)
                                                     name:kPWAppCodeUpdatedNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onActiveApplicationWillChange:)
                                                     name:kPWActiveApplicationWillChangeNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onActiveApplicationChanged:)
                                                     name:kPWActiveApplicationChangedNotification
                                                   object:nil];

#if TARGET_OS_IOS || TARGET_OS_OSX
        _retryPolicy = [PWRetryPolicy new];
        _retryQueue = [[PWRetryQueue alloc] initWithTransport:self
                                                       policy:_retryPolicy
                                                      storage:[PWRetryQueueStorage defaultStorage]];
        [self startReachability];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(onServerCommunicationStarted:)
                                                     name:kPWServerCommunicationStarted
                                                   object:nil];
#endif

        [self evaluateReadiness];
	}

	return self;
}

- (void)startReachability {
#if TARGET_OS_IOS || TARGET_OS_OSX || TARGET_OS_TV
    _reachability = [PWReachability reachabilityForInternetConnection];
    __weak typeof(self) wSelf = self;
    _reachability.reachableBlock = ^(PWReachability *reachability) {
        if (reachability.currentReachabilityStatus != NotReachable) {
            [wSelf.retryQueue onNetworkReachable];
        }
    };
    [_reachability startNotifier];
#endif
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)seedAppCodeFromInfoPlistIfNeeded {
    NSString *currentAppCode = [PWPreferences preferences].appCode;
    if (currentAppCode.length > 0) {
        return;
    }
    NSString *infoPlistAppCode = [PWConfig config].appId;
    if (infoPlistAppCode.length > 0) {
        [PWPreferences preferences].appCode = infoPlistAppCode;
    }
}

/// Single source of both the gate and its diagnostic: a new precondition added here automatically
/// gets a warning, instead of queueing silently until someone remembers the second copy.
- (NSString *)unmetReadinessReason {
    NSString *appCode = [PWPreferences preferences].appCode;
    if (appCode.length == 0) {
        return @"app_code is not set. Call Pushwoosh.configure.setAppCode() or set Pushwoosh_APPID in Info.plist.";
    }
    if ([PWConfig config].allowReverseProxy) {
        BOOL hasProxy;
        @synchronized (self) {
            hasProxy = (_reverseProxyUrl.length > 0);
        }
        if (!hasProxy) {
            return @"reverse proxy URL is not set. Call Pushwoosh.configure.setReverseProxy().";
        }
    }
    return nil;
}

- (BOOL)isReadyForNetwork {
    return [self unmetReadinessReason] == nil;
}

- (void)evaluateReadiness {
    if ([self isReadyForNetwork]) {
        [[PWSdkStateProvider sharedInstance] setReady];
#if TARGET_OS_IOS || TARGET_OS_OSX
        [_retryQueue flush];
#endif
    }
}

- (void)onAppCodeUpdatedNotification:(NSNotification *)notification {
    __weak typeof(self) wSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wSelf evaluateReadiness];
    });
}

- (void)onServerCommunicationStarted:(NSNotification *)notification {
    [_retryQueue flush];
}

/// The code has not moved yet — draining the pending `setTags` wrapper now is what makes its
/// late-serialized body carry the application it was accumulated for.
- (void)onActiveApplicationWillChange:(NSNotification *)notification {
    [self drainCombinedSetTagsRequest];
}

/// Purge only on an actual application change — a URL-only move keeps its queued statistics.
/// An absent flag means "unknown" and purges (fail towards isolation).
- (void)onActiveApplicationChanged:(NSNotification *)notification {
    [self drainCombinedSetTagsRequest];

#if TARGET_OS_IOS || TARGET_OS_OSX
    NSNumber *appCodeChanged = notification.userInfo[kPWActiveApplicationChangedAppCodeChangedKey];
    if (![appCodeChanged isKindOfClass:[NSNumber class]] || appCodeChanged.boolValue) {
        [_retryQueue purgeAllEntriesWithReason:@"active application changed"];
    }
#endif

    __weak typeof(self) wSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [wSelf evaluateReadiness];
    });
}

#pragma mark - Send-time application pin

/// Gated on a record, so installs that never selected an application keep behaving bit-for-bit as
/// before. A `PWReplayRequest` is never pinned — its body and URL are already frozen.
- (void)pinApplicationForRequest:(PWRequest *)request {
    if (request.pinnedAppCode.length > 0) {
        return;
    }
    if ([request isKindOfClass:[PWReplayRequest class]]) {
        return;
    }
    if (![PWPreferences hasActiveApplicationRecord]) {
        return;
    }

    NSDictionary *pair = [[PWPreferences preferences] activeApplicationSnapshot];
    NSString *appCode = pair[kPWActiveApplicationAppCodeKey];
    if (appCode.length > 0) {
        request.pinnedAppCode = appCode;
    }

    if (request.pinnedBaseUrl.length == 0) {
        /// BOTH halves come from the one snapshot, or a racing switch could pin one application's code
        /// next to the other's host. A reverse proxy is a transport-level override and still wins.
        NSString *currentUrl = [self isUsingReverseProxy] ? [self baseUrl] : pair[kPWActiveApplicationBaseUrlKey];
        if (currentUrl.length > 0) {
            request.pinnedBaseUrl = currentUrl;
        }
    }

    if (request.pinnedAppCode.length > 0) {
        [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self
                           message:[NSString stringWithFormat:@"Pinned %@ to %@ @ %@", request.methodName, request.pinnedAppCode, request.pinnedBaseUrl ?: @"(current)"]];
    }
}

/// The gRPC host is fixed by `Pushwoosh_GRPC_HOST` and cannot follow a runtime switch, so fall back
/// to REST when the selected endpoint differs (ADR-12).
- (BOOL)shouldBypassGRPCForRequest:(PWRequest *)request {
    if (![PWPreferences hasActiveApplicationRecord]) {
        return NO;
    }

    NSString *targetUrl = request.pinnedBaseUrl ?: [self baseUrl];
    NSString *targetHost = targetUrl.length > 0 ? [NSURL URLWithString:targetUrl].host : nil;
    NSString *grpcHost = [PWConfig config].grpcHost;

    if (targetHost.length == 0 || grpcHost.length == 0 || [targetHost isEqualToString:grpcHost]) {
        return NO;
    }

    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:[NSString stringWithFormat:@"A Pushwoosh application was selected at runtime, but the gRPC transport is fixed to \"%@\" and cannot follow it. Falling back to REST so requests reach \"%@\". Point Pushwoosh_GRPC_HOST at a host valid for every application, or do not link PushwooshGRPC.", grpcHost, targetHost]];
    });

    return YES;
}

/// Freezes the replay host only once the integrator owns the pair; without a record the stamp
/// stays exactly as before (nil = replay against the current URL).
- (NSString *)frozenBaseUrlForRetryOf:(PWRequest *)request {
    if (![PWPreferences hasActiveApplicationRecord]) {
        return [request baseUrl];
    }

    return [request baseUrl] ?: [self baseUrl];
}

/// Called only for a request the provider actually queued, so the "will be queued" tail is always true.
/// Warned once per reason, so a second unmet condition is still announced after the first one is fixed.
- (void)logQueueWarnIfNeeded:(PWRequest *)request {
    NSString *reason = [self unmetReadinessReason];
    if (reason != nil && [self shouldWarnOnceForKey:reason inSet:_warnedQueueReasons]) {
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:[NSString stringWithFormat:@"Pushwoosh SDK is not ready yet - %@ Requests will be queued until the SDK is ready.", reason]];
    }

    [PushwooshLog pushwooshLog:PW_LL_DEBUG
                     className:self
                       message:[NSString stringWithFormat:@"Queuing %@ until SDK is ready.", request.methodName]];
}

/// YES the first time a key is seen, NO afterwards. Shared by the queue-readiness and the shard-rotation
/// warnings so a change to the once-per-key policy lands in one place.
- (BOOL)shouldWarnOnceForKey:(NSString *)key inSet:(NSMutableSet<NSString *> *)seen {
    @synchronized (self) {
        if ([seen containsObject:key]) {
            return NO;
        }
        [seen addObject:key];
        return YES;
    }
}

- (BOOL)isGRPCAvailable {
    if (_grpcTransportClass == nil) {
        _grpcTransportClass = NSClassFromString(@"PushwooshGRPC.PushwooshGRPCImplementation");
    }

    if (_grpcTransportClass) {
        SEL isAvailableSel = @selector(isAvailable);
        if ([_grpcTransportClass respondsToSelector:isAvailableSel]) {
            return ((BOOL (*)(Class, SEL))[(id)_grpcTransportClass methodForSelector:isAvailableSel])(_grpcTransportClass, isAvailableSel);
        }
    }

    return NO;
}

- (BOOL)grpcSupportsMethod:(NSString *)methodName {
    if (_grpcTransportClass == nil) {
        return NO;
    }

    SEL supportsMethodSelector = NSSelectorFromString(@"supportsMethod:");
    if ([_grpcTransportClass respondsToSelector:supportsMethodSelector]) {
        typedef BOOL (*SupportsMethodIMP)(Class, SEL, NSString *);
        SupportsMethodIMP supportsMethod = (SupportsMethodIMP)[_grpcTransportClass methodForSelector:supportsMethodSelector];
        return supportsMethod(_grpcTransportClass, supportsMethodSelector, methodName);
    }

    return NO;
}

- (NSString *)baseUrl {
    @synchronized (self) {
        if (_reverseProxyUrl) {
            return _reverseProxyUrl;
        }
    }
	return [PWPreferences preferences].baseUrl;
}

- (BOOL)isUsingReverseProxy {
    @synchronized (self) {
        return _reverseProxyUrl.length > 0;
    }
}

- (void)setReverseProxyUrl:(NSString *)url headers:(NSDictionary<NSString *, NSString *> *)headers {
    if (!url || url.length == 0) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"setReverseProxy() ignored: URL must not be nil or empty"];
        return;
    }
    if (![url hasPrefix:@"https://"] && ![url hasPrefix:@"http://"]) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"setReverseProxy() ignored: URL must start with https:// or http://"];
        return;
    }
    NSURL *parsed = [NSURL URLWithString:url];
    if (!parsed) {
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"setReverseProxy() ignored: malformed URL"];
        return;
    }
    if (![url hasSuffix:@"/"]) {
        url = [url stringByAppendingString:@"/"];
    }
    @synchronized (self) {
        _reverseProxyUrl = [url copy];
        _customHeaders = headers ? [headers copy] : @{};
    }

    [self saveSharedReverseProxyUrl:url headers:headers];

    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"Reverse proxy configured: %@", url]];

    if ([PWConfig config].allowReverseProxy) {
        [self evaluateReadiness];
    }
}

#pragma mark - App Groups (for NSE)

- (void)saveSharedReverseProxyUrl:(NSString *)url headers:(NSDictionary *)headers {
    NSString *appGroupsName = [[PWConfig config] appGroupsName];
    if (!appGroupsName || appGroupsName.length == 0) {
        return;
    }
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:appGroupsName];
    [sharedDefaults setObject:url forKey:kPWSharedReverseProxyURLKey];
    [sharedDefaults setObject:headers forKey:kPWSharedCustomHeadersKey];
}

- (void)clearSharedReverseProxySettings {
    NSString *appGroupsName = [[PWConfig config] appGroupsName];
    if (!appGroupsName || appGroupsName.length == 0) {
        return;
    }
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:appGroupsName];
    [sharedDefaults removeObjectForKey:kPWSharedReverseProxyURLKey];
    [sharedDefaults removeObjectForKey:kPWSharedCustomHeadersKey];
}

- (void)loadReverseProxyFromAppGroups {
    [self loadReverseProxyFromAppGroups:nil];
}

- (void)loadReverseProxyFromAppGroups:(NSString *)appGroupsName {
    if (appGroupsName.length == 0) {
        appGroupsName = [[PWConfig config] appGroupsName];
    }
    if (appGroupsName.length == 0) {
        return;
    }
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:appGroupsName];
    NSString *sharedProxyUrl = [sharedDefaults stringForKey:kPWSharedReverseProxyURLKey];
    NSDictionary *sharedHeaders = [sharedDefaults objectForKey:kPWSharedCustomHeadersKey];

    if (sharedProxyUrl && sharedProxyUrl.length > 0) {
        @synchronized (self) {
            _reverseProxyUrl = [sharedProxyUrl copy];
            _customHeaders = [sharedHeaders isKindOfClass:[NSDictionary class]] ? [sharedHeaders copy] : @{};
        }
        if ([PWConfig config].allowReverseProxy) {
            [self evaluateReadiness];
        }
    } else if ([PWConfig config].allowReverseProxy) {
        BOOL hasProxy;
        @synchronized (self) {
            hasProxy = (_reverseProxyUrl.length > 0);
        }
        if (!hasProxy) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:[NSString stringWithFormat:@"Reverse proxy is enabled but no proxy URL was found in App Group \"%@\". Network requests — including the message delivery event from the Notification Service Extension — will be held until the host app stores the proxy URL there. Make sure the extension has the App Group capability and the host app has called setReverseProxyUrl.", appGroupsName]];
        }
    }
}

- (void)sendRequest:(PWRequest *)request completion:(void (^)(NSError *error))completion {
    __weak typeof(self) wSelf = self;
    PWSdkQueueDecision decision = [[PWSdkStateProvider sharedInstance] queueUnlessReady:^{
        [wSelf sendRequest:request completion:completion];
    }];

    if (decision == PWSdkQueueDecisionQueued) {
        [self logQueueWarnIfNeeded:request];
        return;
    }

    if (decision == PWSdkQueueDecisionDropped) {
        return;
    }

    [self pinApplicationForRequest:request];

    // Use gRPC automatically when module is linked and supports this method
    if ([self isGRPCAvailable] && [self grpcSupportsMethod:request.methodName] && ![self shouldBypassGRPCForRequest:request]) {
        [self sendRequestViaGRPC:request completion:completion];
        return;
    }

    // Default REST transport
    if ([request isKindOfClass:[PWSetTagsRequest class]]) {
        PWSetTagsRequest *setTagsRequest = (PWSetTagsRequest *)request;
        [self sendTags:setTagsRequest completion:completion];
    } else {
        [self sendRequestInternal:request completion:completion];
    }
}

- (void)sendRequestViaGRPC:(PWRequest *)request completion:(void (^)(NSError *error))completion {
    if (!_grpcTransportClass) {
        // Fallback to REST
        if ([request isKindOfClass:[PWSetTagsRequest class]]) {
            PWSetTagsRequest *setTagsRequest = (PWSetTagsRequest *)request;
            [self sendTags:setTagsRequest completion:completion];
        } else {
            [self sendRequestInternal:request completion:completion];
        }
        return;
    }

    __weak typeof(self) wSelf = self;

    SEL sendRequestSelector = NSSelectorFromString(@"sendRequest:completion:");
    if ([_grpcTransportClass respondsToSelector:sendRequestSelector]) {
        // Use performSelector or direct invocation via IMP
        typedef void (*SendRequestIMP)(Class, SEL, PWRequest*, void (^)(NSDictionary*, NSError*));
        SendRequestIMP sendRequest = (SendRequestIMP)[_grpcTransportClass methodForSelector:sendRequestSelector];

        sendRequest(_grpcTransportClass, sendRequestSelector, request, ^(NSDictionary *response, NSError *error) {
            if (error) {
                // Log gRPC error and optionally fallback to REST
                [PushwooshLog pushwooshLog:PW_LL_WARN
                                 className:wSelf
                                   message:[NSString stringWithFormat:@"gRPC request failed: %@, falling back to REST", error.localizedDescription]];

                // Fallback to REST on error
                if ([request isKindOfClass:[PWSetTagsRequest class]]) {
                    PWSetTagsRequest *setTagsRequest = (PWSetTagsRequest *)request;
                    [wSelf sendTags:setTagsRequest completion:completion];
                } else {
                    [wSelf sendRequestInternal:request completion:completion];
                }
                return;
            }

            // Process gRPC response
            request.httpCode = [response[@"status_code"] integerValue];

            if (request.httpCode != 200) {
                NSString *statusMessage = response[@"status_message"];
                NSError *statusError = [PWUtils pushwooshError:statusMessage ?: @"gRPC request failed"];
#if TARGET_OS_IOS || TARGET_OS_OSX
                if (request.cacheable && [wSelf.retryPolicy shouldRetryStatusCode:request.httpCode error:statusError]) {
                    [wSelf.retryQueue enqueueRequest:request baseUrl:[wSelf frozenBaseUrlForRetryOf:request]];
                }
#endif
                if (completion) {
                    completion(statusError);
                }
                return;
            }

            // Parse response if present
            NSDictionary *responseDict = response[@"response"];
            if ([responseDict isKindOfClass:[NSDictionary class]]) {
                [request parseResponse:responseDict];
            }

            // Handle base_url switch
            [wSelf applyServerBaseUrl:response[@"base_url"] forRequest:request];

            if (completion) {
                completion(nil);
            }
        });
    } else {
        // Fallback to REST if method not available
        if ([request isKindOfClass:[PWSetTagsRequest class]]) {
            PWSetTagsRequest *setTagsRequest = (PWSetTagsRequest *)request;
            [self sendTags:setTagsRequest completion:completion];
        } else {
            [self sendRequestInternal:request completion:completion];
        }
    }
}

#pragma mark - PWRetryTransport

- (NSString *)currentBaseUrlForRetry {
    return [self baseUrl];
}

- (void)sendRetryEntry:(PWRetryEntry *)entry completion:(void (^)(NSInteger statusCode, NSError *error))completion {
    if (![[PWSdkStateProvider sharedInstance] isReady]) {
        if (completion) {
            completion(0, [PWUtils pushwooshErrorWithCode:PWErrorRequestNotReady description:@"SDK not ready; retry deferred"]);
        }
        return;
    }

    PWReplayRequest *request = [[PWReplayRequest alloc] initWithMethodName:entry.methodName
                                                        requestDictionary:entry.requestDictionary
                                                        requestIdentifier:entry.requestIdentifier
                                                        shouldWrapRequest:entry.shouldWrapRequest
                                                                  baseUrl:entry.baseUrl];
    request.retryCount = (NSInteger)(entry.attemptCount + 1);
    [self sendRequestInternal:request completion:^(NSError *error) {
        if (completion) {
            completion(request.httpCode, error);
        }
    }];
}

- (void)sendTags:(PWSetTagsRequest *)request completion:(void (^)(NSError *error))completion {
	@synchronized(_sendTagsLock) {
		BOOL scheduledSendTags = NO;
		if (!_combinedRequest) {
			_combinedRequest = [PWCombinedSetTagsRequest new];
			[self pinApplicationForRequest:_combinedRequest];
			scheduledSendTags = YES;
		}

		[_combinedRequest addRequest:request];

		if (completion) {
			[_sendTagsCompletions addObject:completion];
		}

		if (scheduledSendTags) {
			PWCombinedSetTagsRequest *scheduledRequest = _combinedRequest;
			__weak typeof(self) wSelf = self;
			dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
				[wSelf drainCombinedSetTagsRequestIfCurrent:scheduledRequest];
			});
		}
	}
}

/// Flushes the one-second `setTags` coalescing window immediately, so an application switch cannot
/// merge the next application's tags into a wrapper opened under the previous one.
- (void)drainCombinedSetTagsRequest {
	[self drainCombinedSetTagsRequestIfCurrent:nil];
}

/// `expected` == nil drains whatever is pending; otherwise only the wrapper the caller scheduled,
/// so a stale timer cannot truncate the next window. Extract under the lock, send outside it.
- (void)drainCombinedSetTagsRequestIfCurrent:(PWCombinedSetTagsRequest *)expected {
	PWCombinedSetTagsRequest *pending = nil;
	NSArray *completions = nil;

	@synchronized(_sendTagsLock) {
		if (_combinedRequest == nil) {
			return;
		}
		if (expected != nil && _combinedRequest != expected) {
			return;
		}
		pending = _combinedRequest;
		completions = [_sendTagsCompletions copy];
		_combinedRequest = nil;
		[_sendTagsCompletions removeAllObjects];
	}

	[self sendRequestInternal:pending completion:^void(NSError *error) {
		for (void (^handler)(NSError *error) in completions) {
			handler(error);
		}
	}];
}

- (void)persistRequestForLaterRetry:(PWRequest *)request {
#if TARGET_OS_IOS || TARGET_OS_OSX
    [_retryQueue enqueueRequest:request baseUrl:[self frozenBaseUrlForRetryOf:request]];
#endif
}

- (void)sendRequestInternal:(PWRequest *)request completion:(void (^)(NSError *error))completion {
    [self pinApplicationForRequest:request];

    //check server communication enabled
    if (![[PWServerCommunicationManager sharedInstance] isServerCommunicationAllowed]) {
        NSString *errorStr = @"Communication with Pushwoosh is disabled. To send the request you have to enable the server communication using method startServerCommunication of Pushwoosh class.";
        if (completion) {
            completion([PWUtils pushwooshErrorWithCode:PWErrorCommunicationDisabled description:errorStr]);
        } else {
            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorStr];
        }
        return;
    }

    __weak typeof (self) wSelf = self;
#if TARGET_OS_IOS
    __block NSInteger backgroundTaskId = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
        backgroundTaskId = UIBackgroundTaskInvalid;
    }];
#endif
    
    //request part
    NSString *base = [request baseUrl] ?: [self baseUrl];
    if (base.length == 0) {
        NSString *errorStr = [NSString stringWithFormat:@"Base URL is not configured yet. Request blocked: %@", request.methodName];
        [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:errorStr];
        if (completion) {
            completion([PWUtils pushwooshErrorWithCode:PWErrorRequestNotReady description:errorStr]);
        }
#if TARGET_OS_IOS
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
        return;
    }
    if (![base hasSuffix:@"/"]) {
        base = [base stringByAppendingString:@"/"];
    }
    NSString *requestUrl = [base stringByAppendingString:[request methodName]];

    [request setStartTime:[[NSDate date] timeIntervalSince1970]];

    if (![NSJSONSerialization isValidJSONObject:request.requestDictionary]) {
        NSString *errorStr = [NSString stringWithFormat:@"Failed to serialize request %@: non-serializable data", request.methodName];
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorStr];
        if (completion) {
            completion([PWUtils pushwooshError:errorStr]);
        }
#if TARGET_OS_IOS
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
        return;
    }

    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:request.requestDictionary options:0 error:&jsonError];

    if (!jsonData || jsonError) {
        NSString *errorStr = [NSString stringWithFormat:@"Failed to serialize request: %@", jsonError.localizedDescription ?: @"unknown error"];
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorStr];
        if (completion) {
            completion([PWUtils pushwooshError:errorStr]);
        }
#if TARGET_OS_IOS
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
        return;
    }

    NSString *requestString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSString *requestData = [request shouldWrapRequest]
        ? [NSString stringWithFormat:@"{\"request\":%@}", requestString]
        : requestString;

    NSMutableURLRequest *urlRequest = [self prepareRequest:requestUrl jsonRequestData:requestData];

    if (!urlRequest || !urlRequest.URL) {
        NSString *errorStr = [NSString stringWithFormat:@"Invalid request URL: %@", requestUrl];
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:errorStr];
        if (completion) {
            completion([PWUtils pushwooshError:errorStr]);
        }
#if TARGET_OS_IOS
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
        return;
    }

    if (request.retryCount > 0) {
        [urlRequest setValue:[NSString stringWithFormat:@"%ld", (long)request.retryCount] forHTTPHeaderField:@"X-Retry-Count"];
    }

    NSURLSession *session = request.retryCount > 0 ? _retrySession : _session;
    NSURLSessionDataTask *postDataTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

#if TARGET_OS_IOS || TARGET_OS_OSX
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
        if (request.cacheable && [wSelf.retryPolicy shouldRetryStatusCode:httpResponse.statusCode error:error]) {
            request.httpCode = httpResponse.statusCode;
            [wSelf.retryQueue enqueueRequest:request baseUrl:[wSelf frozenBaseUrlForRetryOf:request]];

            if (completion) {
                NSError *reportedError = error ?: [PWUtils pushwooshError:[NSString stringWithFormat:@"Request %@ failed with status code %ld and was queued for retry", request.methodName, (long)httpResponse.statusCode]];
                completion(reportedError);
            }

#if TARGET_OS_IOS
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
            return;
        }
#endif
                
        [wSelf processResponse:(NSHTTPURLResponse *)response responseData:data request:request url:requestUrl requestData:requestData error:&error];
        
		if (completion)
			completion(error);
		
#if TARGET_OS_IOS
		[[UIApplication sharedApplication] endBackgroundTask:backgroundTaskId];
#endif
		}
	];

	[postDataTask resume];
}

/// The single decision point (REST + gRPC) for whether a server-supplied `base_url` may move the
/// effective endpoint: never from a replay, never from an application the device has since left.
- (void)applyServerBaseUrl:(id)newBaseUrl forRequest:(PWRequest *)request {
    if (![newBaseUrl isKindOfClass:[NSString class]]) {
        return;
    }

    if ([request isKindOfClass:[PWReplayRequest class]]) {
        [PushwooshLog pushwooshLog:PW_LL_INFO
                         className:self
                           message:[NSString stringWithFormat:@"Ignoring base_url from the replay of %@: a replayed request must not move the endpoint", request.methodName]];
        return;
    }

    /// Verdict and write are one operation on the preferences side — check-then-write here would
    /// leave a window for a racing switch.
    NSString *applied = [[PWPreferences preferences] updateBaseUrl:newBaseUrl
                                     ifSelectedPairMatchesAppCode:request.pinnedAppCode
                                                          baseUrl:request.pinnedBaseUrl];
    if (applied == nil) {
        [PushwooshLog pushwooshLog:PW_LL_INFO
                         className:self
                           message:[NSString stringWithFormat:@"Ignoring base_url \"%@\" from %@: the response belongs to a Pushwoosh application that is no longer active, or the URL was rejected", newBaseUrl, request.methodName]];
        return;
    }

    [self warnOnceIfServerBaseUrlLeavesSelectedDomain:applied];
}

/// Log-only, one WARN per new host: a hostile rotation and a legitimate shard rotation are
/// indistinguishable at the client, and blocking would break real migrations (ADR-14).
- (void)warnOnceIfServerBaseUrlLeavesSelectedDomain:(NSString *)newBaseUrl {
    if (![PWPreferences hasActiveApplicationRecord]) {
        return;
    }

    NSString *newHost = [NSURL URLWithString:newBaseUrl].host;
    if (newHost.length == 0) {
        return;
    }

    PWPreferences *preferences = [PWPreferences preferences];
    NSString *selectedUrl = [preferences selectedBaseUrl] ?: [preferences defaultBaseUrl];
    NSString *selectedHost = selectedUrl.length > 0 ? [NSURL URLWithString:selectedUrl].host : nil;
    if (selectedHost.length == 0) {
        return;
    }

    NSString *selectedDomain = [self registrableDomainOfHost:selectedHost];
    if ([[self registrableDomainOfHost:newHost] isEqualToString:selectedDomain]) {
        return;
    }

    if (![self shouldWarnOnceForKey:newHost inSet:_warnedRotationHosts]) {
        return;
    }

    [PushwooshLog pushwooshLog:PW_LL_WARN
                     className:self
                       message:[NSString stringWithFormat:@"The server moved Pushwoosh traffic to \"%@\", which is outside the domain of the selected application (\"%@\"). The move was applied - shard rotations are legitimate - but if it was not expected, call Pushwoosh.configure.setAppCode(<code>, baseUrl:) again with your own endpoint to return to it.", newHost, selectedDomain]];
}

/// Last-two-labels approximation (no bundled public suffix list): under-warns for suffixes like
/// `co.uk`, the right bias for a log-only signal.
- (NSString *)registrableDomainOfHost:(NSString *)host {
    NSArray<NSString *> *labels = [host componentsSeparatedByString:@"."];
    if (labels.count <= 2) {
        return host;
    }
    return [NSString stringWithFormat:@"%@.%@", labels[labels.count - 2], labels[labels.count - 1]];
}

/// One-shot: a gateway that strips `status_code` from every reply would otherwise fill production
/// logs with the same line.
- (void)logSuppressedMissingStatusCodeResetOnce:(PWRequest *)request {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [PushwooshLog pushwooshLog:PW_LL_WARN
                         className:self
                           message:[NSString stringWithFormat:@"Response to %@ carries no status_code. Keeping the endpoint of the selected Pushwoosh application instead of falling back to the default one. This is logged once per app run.", request.methodName]];
    });
}

- (NSMutableURLRequest *)prepareRequest:(NSString *)requestUrl jsonRequestData:(NSString *)jsonRequestData {
    NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:requestUrl]];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setHTTPBody:[jsonRequestData dataUsingEncoding:NSUTF8StringEncoding]];

    // Custom headers first, so SDK headers cannot be overridden
    NSDictionary<NSString *, NSString *> *headers;
    NSString *proxyUrl;
    @synchronized (self) {
        headers = [_customHeaders copy];
        proxyUrl = _reverseProxyUrl;
    }
    if (proxyUrl) {
        for (NSString *key in headers) {
            [urlRequest setValue:headers[key] forHTTPHeaderField:key];
        }
    }

    // SDK headers last — always take precedence
    [urlRequest setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    NSString *apiToken = [self getApiToken] ?: [self getConfigApiToken];
    [urlRequest setValue:[NSString stringWithFormat:@"Token %@", apiToken] forHTTPHeaderField:@"Authorization"];

    return urlRequest;
}

- (NSString *)getApiToken {
    return [[PWConfig config] pushwooshApiToken] ? [[PWConfig config] pushwooshApiToken] : [[PWConfig config] apiToken];
}

- (NSString *)getConfigApiToken {
    return [PushwooshConfig getApiToken];
}

- (void)processResponse:(NSHTTPURLResponse *)httpResponse responseData:(NSData *)responseData request:(PWRequest *)request url:(NSString *)requestUrl requestData:(NSString *)requestData error:(NSError **)outError {
    
	NSError *error = *outError;
	request.httpCode = httpResponse.statusCode;
        
    if (error == nil) {
        NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
        NSString *requestLogStr = [NSString stringWithFormat:@"\n"
                                     @"x\n"
                                     @"|    Pushwoosh request:\n"
                                     @"| Url:      %@\n"
                                     @"| Payload:  %@\n"
                                     @"| Status:   \"%ld %@\"\n"
                                     @"| Response: %@\n"
                                     @"x",
                                     requestUrl, requestData, (long)[httpResponse statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]], responseString];
        
        
        [PushwooshLog pushwooshLog:PW_LL_DEBUG
                         className:self
                           message:requestLogStr];
        
        NSDictionary *jsonResult = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        
        if (![jsonResult isKindOfClass:[NSDictionary class]]) {
			if (error == nil) {
				error = [PWUtils pushwooshError:@"Bad response body"];
			}
		} else {
			// honor base url switch
            BOOL isUsingProxy;
            @synchronized (self) {
                isUsingProxy = (_reverseProxyUrl != nil);
            }
            BOOL hasActiveApplication = [PWPreferences hasActiveApplicationRecord];
			if (jsonResult[@"status_code"] == nil && !isUsingProxy) {
                if (hasActiveApplication) {
                    [self logSuppressedMissingStatusCodeResetOnce:request];
                } else {
                    NSString *defaultUrl = [[PWPreferences preferences] defaultBaseUrl];
                    if (defaultUrl.length > 0) {
                        [[PWPreferences preferences] updateBaseUrl:defaultUrl];
                    }
                }
			}
            if (!isUsingProxy) {
                [self applyServerBaseUrl:jsonResult[@"base_url"] forRequest:request];
			}
            
			// check status
			if (httpResponse.statusCode != 200 || ![jsonResult[@"status_code"] isKindOfClass:[NSNumber class]] || [jsonResult[@"status_code"] intValue] != 200) {
                
                NSString *statusMessage = jsonResult[@"status_message"];
                
                if (statusMessage) {
                    error = [PWUtils pushwooshError:statusMessage];
                } else {
                    error = [PWUtils pushwooshError:[NSString stringWithFormat:@"Bad response status code: (%d, %@)", (int)httpResponse.statusCode, jsonResult[@"status_code"]]];
                }
			} else {
				// optional response parsing
				NSDictionary *responseDict = jsonResult[@"response"];
                
                if ([responseDict isKindOfClass:[NSDictionary class]]) {
                    #ifdef DEBUG
                    [request parseResponse:responseDict];
                    #else
                    @try {
                        [request parseResponse:responseDict];
                    }
                    @catch (NSException *exception) {
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@""];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              |      |"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              |      |"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              |      |"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              |      |"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              |      |"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"          ====        ===="];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"          \\              /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"           \\            /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"            \\          /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"             \\        /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"              \\      /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"               \\    /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"                \\  /"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@"                 \\/"];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:@""];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Fail to parse response: %@", responseDict]];
                        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Catched exception: %@", exception]];
                    }
                    #endif
                }
			}
		}
	} else {
        [PushwooshLog pushwooshLog:PW_LL_ERROR
                         className:self
                           message:[NSString stringWithFormat:@"Sending %@ failed, %@", request.methodName, error.description]];
	}

	*outError = error;
}

- (void)downloadDataFromURL:(NSURL *)url withCompletion:(PWRequestDownloadCompleteBlock)completion {
    [PushwooshLog pushwooshLog:PW_LL_DEBUG
                     className:self
                       message:[NSString stringWithFormat:@"Pushwoosh In-App: will download data:%@\n", url.absoluteString]];

	[[_session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
		if (!completion)
			return;

		if (error) {
            [PushwooshLog pushwooshLog:PW_LL_ERROR
                             className:self
                               message:[NSString stringWithFormat:@"Pushwoosh In-App failed to download data: %@", error.localizedDescription]];
			completion(nil, error);
		} else {
			completion(location.path, nil);
		}
	}] resume];
}

- (NSString *)getStringOrEmpty:(NSString *)string {
    return string != nil ? string : @"";
}

@end
