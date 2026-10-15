//  PWFeatureFlagsTest.m
//  Created by André Kis

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PushwooshFramework.h"
#import "Pushwoosh+Internal.h"
#import "PWConfig.h"
#import "PWFeatureFlags.h"
#import "PWFeatureFlagsManager.h"
#import "PWInAppManager.h"
#import "PWInAppMessagesManager.h"
#import "PWManagerBridge.h"
#import "PWNetworkModule.h"
#import "PWNotificationManagerCompat.h"
#import "PWPlatformModule.h"
#import "PWPreferences.h"
#import "PWPushNotificationsManager.common.h"
#import "PWRequestManager.h"
#import "PWSdkStateProvider.h"
#import "PWUtils.h"

static NSString *const kTestAppCode = @"FFTST-00001";
static NSString *const kTestBaseUrl = @"https://ffhost.example.com/json/1.3/";
static NSTimeInterval const kMinute = 60;
static NSTimeInterval const kHour = 60 * 60;

@interface PWSdkStateProvider (FeatureFlagsTest)
- (void)resetForTesting;
@end

@interface PWConfig (FeatureFlagsTest)
- (void)setLazyInitialization:(BOOL)lazyInitialization;
@end

@interface PWRequestManager (FeatureFlagsTest)
@property (nonatomic, strong) NSURLSession *session;
@end

@interface PWFeatureFlagsManager (Test)
@property (nonatomic, copy) NSTimeInterval (^clock)(void);
@property (nonatomic, copy) void (^scheduler)(NSTimeInterval delay, dispatch_block_t fire);
@property (nonatomic) BOOL inAppExtension;
@property (nonatomic, copy) BOOL (^applicationActive)(void);
- (void)resetForTesting;
@end

@interface PWPushNotificationsManagerCommon (FeatureFlagsTest)
- (void)sendDevTokenToServer:(NSString *)deviceID triggerCallbacks:(BOOL)triggerCallbacks;
@end

@interface PWInAppMessagesManager (FeatureFlagsTest)
- (void)sendInitRequests;
- (void)setUserId:(NSString *)userId completion:(void (^)(NSError *error))completion;
@end

@interface PWFeatureFlagsTestListener : NSObject <PWFeatureFlagsUpdateListener>
@property (nonatomic, strong) NSMutableArray<NSNumber *> *calls;
@end

@implementation PWFeatureFlagsTestListener

- (instancetype)initWithCalls:(NSMutableArray<NSNumber *> *)calls {
    self = [super init];
    if (self) {
        _calls = calls;
    }
    return self;
}

- (void)featureFlagsDidUpdate {
    [_calls addObject:@([NSThread isMainThread])];
}

@end

@interface PWFeatureFlagsTestReply : NSObject
@property (nonatomic) NSInteger status;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, strong) NSError *error;
@end

@implementation PWFeatureFlagsTestReply
@end

@interface PWFeatureFlagsTestVoIPRegistration : PWRequest
@end

@implementation PWFeatureFlagsTestVoIPRegistration

- (NSString *)methodName {
    return @"registerDevice";
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [self baseDictionary];
    dict[@"voip_push_token"] = @"ff-voip-token";
    return dict;
}

@end

@interface PWFeatureFlagsTest : XCTestCase

@property (nonatomic, strong) PWRequestManager *requestManager;
@property (nonatomic, strong) id sessionMock;
@property (nonatomic, strong) NSMutableArray<NSURLRequest *> *sentRequests;
@property (nonatomic, strong) NSMutableArray<PWFeatureFlagsTestReply *> *replies;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *heldReplies;
@property (nonatomic) BOOL holdReplies;
@property (nonatomic) NSTimeInterval now;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *scheduledDelays;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *scheduledTimers;

@property (nonatomic, copy) NSString *savedAppCode;
@property (nonatomic, copy) NSString *savedUserId;
@property (nonatomic, copy) NSString *savedBaseUrl;
@property (nonatomic, copy) NSDictionary *savedActiveApplicationRecord;
@property (nonatomic, copy) NSDate *savedLastRegisterUserDate;

@property (nonatomic, strong) id userManagerMock;
@property (nonatomic, strong) id inAppManagerMock;
@property (nonatomic, strong) PWInAppManager *savedInAppManager;
@property (nonatomic) BOOL registerUserFails;
@property (nonatomic) BOOL holdRegisterUser;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *heldRegisterUser;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *listenerCalls;
@property (nonatomic, strong) NSMutableArray<NSURLRequest *> *postedEvents;
@property (nonatomic) BOOL postEventFails;
@property (nonatomic) BOOL holdPostEvents;
@property (nonatomic, strong) NSMutableArray<void (^)(BOOL succeeded)> *heldPostEvents;
@property (nonatomic) BOOL serverCommunicationStopped;
@property (nonatomic, strong) id logMock;
@property (nonatomic, strong) id savedDeviceRestoredKey;
@property (nonatomic, strong) id utilsMock;
@property (nonatomic, strong) id compatMock;
@property (nonatomic, strong) PWNotificationManagerCompat *savedCompat;
@property (nonatomic, copy) NSDate *savedLastRegTime;
@property (nonatomic, copy) NSString *savedPushToken;
@property (nonatomic) NSInteger savedLastStatusMask;
@property (nonatomic) BOOL savedLazyInitialization;

@end

@implementation PWFeatureFlagsTest

- (void)setUp {
    [super setUp];

    _savedAppCode = [[PWPreferences preferences].appCode copy];
    _savedUserId = [[PWPreferences preferences].userId copy];
    _savedBaseUrl = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];
    _savedActiveApplicationRecord = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_ACTIVE_APPLICATION"] copy];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];

    _savedLastRegisterUserDate = [PWPreferences preferences].lastRegisterUserDate;
    _savedLazyInitialization = [PWConfig config].lazyInitialization;

    [PWPreferences preferences].appCode = kTestAppCode;
    [PWPreferences preferences].userId = @"user-A";
    [PWPreferences preferences].lastRegisterUserDate = [NSDate date];
    [[PWPreferences preferences] updateBaseUrl:kTestBaseUrl];

    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [[PWSdkStateProvider sharedInstance] setReady];

    _now = 1700000000;
    __weak typeof(self) wSelf = self;
    PWFeatureFlagsManager *manager = [PWFeatureFlagsManager sharedManager];
    [manager resetForTesting];
    manager.clock = ^NSTimeInterval {
        return wSelf.now;
    };
    _scheduledDelays = [NSMutableArray new];
    _scheduledTimers = [NSMutableArray new];
    manager.scheduler = ^(NSTimeInterval delay, dispatch_block_t fire) {
        [wSelf.scheduledDelays addObject:@(delay)];
        [wSelf.scheduledTimers addObject:fire];
    };

    _sentRequests = [NSMutableArray new];
    _replies = [NSMutableArray new];
    _heldReplies = [NSMutableArray new];
    _heldRegisterUser = [NSMutableArray new];
    _listenerCalls = [NSMutableArray new];
    _postedEvents = [NSMutableArray new];
    _heldPostEvents = [NSMutableArray new];
    _requestManager = [PWNetworkModule module].requestManager;
    _sessionMock = OCMPartialMock(_requestManager.session);
    OCMStub([_sessionMock dataTaskWithRequest:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSURLRequest *request;
        __unsafe_unretained void (^handler)(NSData *, NSURLResponse *, NSError *);
        [invocation getArgument:&request atIndex:2];
        [invocation getArgument:&handler atIndex:3];
        [wSelf serveRequest:request handler:handler];
    }).andReturn(nil);
}

- (void)tearDown {
    [_logMock stopMocking];
    _logMock = nil;
    [_sessionMock stopMocking];
    _sessionMock = nil;
    if (_inAppManagerMock) {
        [PWManagerBridge shared].inAppManager = _savedInAppManager;
        [_inAppManagerMock stopMocking];
        [_userManagerMock stopMocking];
        if (_savedDeviceRestoredKey) {
            [[NSUserDefaults standardUserDefaults] setObject:_savedDeviceRestoredKey forKey:@"device_restored_key"];
        } else {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"device_restored_key"];
        }
    }
    if (_compatMock) {
        [PWPlatformModule module].notificationManagerCompat = _savedCompat;
        [_compatMock stopMocking];
        [_utilsMock stopMocking];
        [PWPreferences preferences].lastRegTime = _savedLastRegTime;
        [PWPreferences preferences].pushToken = _savedPushToken;
        [PWPreferences preferences].lastStatusMask = _savedLastStatusMask;
    }
    [_requestManager setValue:nil forKey:@"reverseProxyUrl"];
    if (_serverCommunicationStopped) {
        [[PWManagerBridge shared] startServerCommunication];
    }

    [[PWFeatureFlagsManager sharedManager] resetForTesting];
    [[PWConfig config] setLazyInitialization:_savedLazyInitialization];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    if (_savedActiveApplicationRecord) {
        [[NSUserDefaults standardUserDefaults] setObject:_savedActiveApplicationRecord forKey:@"Pushwoosh_ACTIVE_APPLICATION"];
    }
    [PWPreferences preferences].appCode = _savedAppCode;
    [PWPreferences preferences].userId = _savedUserId;
    [PWPreferences preferences].lastRegisterUserDate = _savedLastRegisterUserDate;
    NSString *restoredBaseUrl = _savedBaseUrl.length > 0 ? _savedBaseUrl : [[PWPreferences preferences] defaultBaseUrl];
    if (restoredBaseUrl.length > 0) {
        [[PWPreferences preferences] updateBaseUrl:restoredBaseUrl];
    }
    if (_savedBaseUrl.length == 0) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_BASEURL"];
    }

    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [super tearDown];
}

#pragma mark - Fake server

- (void)serveRequest:(NSURLRequest *)request handler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    if ([request.URL.path hasSuffix:@"/registerUser"]) {
        [self serveRegisterUser:request handler:handler];
        return;
    }
    if ([request.URL.path hasSuffix:@"/postEvent"]) {
        [self servePostEvent:request handler:handler];
        return;
    }
    if (![request.URL.path hasSuffix:@"/getFeatureFlags"]) {
        NSHTTPURLResponse *ok = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:nil headerFields:nil];
        handler([@"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}" dataUsingEncoding:NSUTF8StringEncoding], ok, nil);
        return;
    }

    [_sentRequests addObject:request];
    PWFeatureFlagsTestReply *reply = _replies.firstObject;
    XCTAssertNotNil(reply, @"unexpected getFeatureFlags request");
    if (!reply) {
        return;
    }
    [_replies removeObjectAtIndex:0];

    void (^copiedHandler)(NSData *, NSURLResponse *, NSError *) = [handler copy];
    dispatch_block_t deliver = ^{
        NSHTTPURLResponse *response = reply.error ? nil : [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:reply.status HTTPVersion:nil headerFields:nil];
        copiedHandler([reply.body dataUsingEncoding:NSUTF8StringEncoding], response, reply.error);
    };
    if (_holdReplies) {
        [_heldReplies addObject:deliver];
    } else {
        deliver();
    }
}

- (void)serveRegisterUser:(NSURLRequest *)request handler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    void (^copiedHandler)(NSData *, NSURLResponse *, NSError *) = [handler copy];
    BOOL fails = _registerUserFails;
    dispatch_block_t deliver = ^{
        if (fails) {
            copiedHandler(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]);
            return;
        }
        NSHTTPURLResponse *ok = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:nil headerFields:nil];
        copiedHandler([@"{\"status_code\":200,\"status_message\":\"OK\",\"response\":null}" dataUsingEncoding:NSUTF8StringEncoding], ok, nil);
    };
    if (_holdRegisterUser) {
        [_heldRegisterUser addObject:deliver];
    } else {
        deliver();
    }
}

- (void)servePostEvent:(NSURLRequest *)request handler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    BOOL impression = [[self bodyOfRequest:request][@"request"][@"event"] isEqualToString:@"PW_FeatureFlagImpression"];
    if (impression) {
        [_postedEvents addObject:request];
    }
    void (^copiedHandler)(NSData *, NSURLResponse *, NSError *) = [handler copy];
    void (^complete)(BOOL) = ^(BOOL succeeded) {
        if (!succeeded) {
            copiedHandler(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]);
            return;
        }
        NSHTTPURLResponse *ok = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:nil headerFields:nil];
        copiedHandler([@"{\"status_code\":200,\"status_message\":\"OK\",\"response\":{}}" dataUsingEncoding:NSUTF8StringEncoding], ok, nil);
    };
    if (!impression) {
        complete(YES);
    } else if (_holdPostEvents) {
        [_heldPostEvents addObject:complete];
    } else {
        complete(!_postEventFails);
    }
}

- (void)replyStatus:(NSInteger)status body:(NSString *)body {
    PWFeatureFlagsTestReply *reply = [PWFeatureFlagsTestReply new];
    reply.status = status;
    reply.body = body;
    [_replies addObject:reply];
}

- (void)replyFlags:(NSDictionary *)flags etag:(NSString *)etag notModified:(BOOL)notModified partial:(BOOL)partial {
    NSDictionary *response = @{ @"flags": flags, @"etag": etag, @"not_modified": @(notModified), @"partial": @(partial) };
    [self replyStatus:200 body:[self envelopeWithResponse:response]];
}

- (void)replyFlags:(NSDictionary *)flags etag:(NSString *)etag {
    [self replyFlags:flags etag:etag notModified:NO partial:NO];
}

- (void)replyOffline {
    PWFeatureFlagsTestReply *reply = [PWFeatureFlagsTestReply new];
    reply.error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
    [_replies addObject:reply];
}

- (NSString *)envelopeWithResponse:(NSDictionary *)response {
    NSDictionary *envelope = @{ @"status_code": @200, @"status_message": @"OK", @"response": response };
    NSData *data = [NSJSONSerialization dataWithJSONObject:envelope options:0 error:nil];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)bodyOfRequest:(NSURLRequest *)request {
    return [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil];
}

#pragma mark - Helpers

- (PWFeatureFlags *)featureFlags {
    return [[Pushwoosh configure] featureFlags];
}

- (PWFeatureFlagsManager *)manager {
    return [PWFeatureFlagsManager sharedManager];
}

- (void)post:(NSNotificationName)name {
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:nil];
}

- (void)postApplicationChanged:(NSDictionary *)userInfo {
    [[NSNotificationCenter defaultCenter] postNotificationName:kPWActiveApplicationChangedNotification object:nil userInfo:userInfo];
}

- (void)passThrottle {
    _now += 5 * kMinute;
}

- (void)waitForRequestCount:(NSUInteger)count {
    __weak typeof(self) wSelf = self;
    NSPredicate *reached = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return wSelf.sentRequests.count >= count;
    }];
    [self waitForExpectations:@[ [[XCTNSPredicateExpectation alloc] initWithPredicate:reached object:nil] ] timeout:5];
}

- (void)waitForPostedEventCount:(NSUInteger)count {
    __weak typeof(self) wSelf = self;
    NSPredicate *reached = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return wSelf.postedEvents.count >= count;
    }];
    [self waitForExpectations:@[ [[XCTNSPredicateExpectation alloc] initWithPredicate:reached object:nil] ] timeout:5];
}

- (void)prepareInAppManager {
    if (_inAppManagerMock) {
        return;
    }
    _savedDeviceRestoredKey = [[NSUserDefaults standardUserDefaults] objectForKey:@"device_restored_key"];
    [[NSUserDefaults standardUserDefaults] setObject:[PWPreferences preferences].hwid forKey:@"device_restored_key"];
    _userManagerMock = OCMPartialMock([PWInAppMessagesManager new]);
    OCMStub([_userManagerMock sendInitRequests]);
    PWInAppMessagesManager *userManager = _userManagerMock;
    _inAppManagerMock = OCMClassMock([PWInAppManager class]);
    OCMStub([_inAppManagerMock setUserId:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *userId;
        __unsafe_unretained void (^completion)(NSError *);
        [invocation getArgument:&userId atIndex:2];
        [invocation getArgument:&completion atIndex:3];
        [userManager setUserId:userId completion:completion];
    });
    OCMStub([_inAppManagerMock setUserId:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *userId;
        [invocation getArgument:&userId atIndex:2];
        [userManager setUserId:userId completion:nil];
    });
    OCMStub([_inAppManagerMock postEvent:OCMOCK_ANY withAttributes:OCMOCK_ANY completion:OCMOCK_ANY]).andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSString *event;
        __unsafe_unretained NSDictionary *attributes;
        __unsafe_unretained void (^completion)(NSError *);
        [invocation getArgument:&event atIndex:2];
        [invocation getArgument:&attributes atIndex:3];
        [invocation getArgument:&completion atIndex:4];
        [userManager postEvent:event withAttributes:attributes completion:completion];
    });
    _savedInAppManager = [PWManagerBridge shared].inAppManager;
    [PWManagerBridge shared].inAppManager = _inAppManagerMock;
}

- (void)prepareDeviceRegistration {
    _savedLastRegTime = [PWPreferences preferences].lastRegTime;
    _savedPushToken = [PWPreferences preferences].pushToken;
    _savedLastStatusMask = [PWPreferences preferences].lastStatusMask;
    _utilsMock = OCMClassMock([PWUtils class]);
    OCMStub([_utilsMock getStatusesMask]).andReturn(0);
    _savedCompat = [PWPlatformModule module].notificationManagerCompat;
    _compatMock = OCMClassMock([PWNotificationManagerCompat class]);
    OCMStub([_compatMock getRemoteNotificationStatusWithCompletion:([OCMArg invokeBlockWithArgs:@{}, nil])]);
    [PWPlatformModule module].notificationManagerCompat = _compatMock;
}

- (void)initializeSdkWithLazyInitialization:(BOOL)lazyInitialization applicationActive:(BOOL)active {
    if (!_compatMock) {
        [self prepareDeviceRegistration];
    }
    [[PWConfig config] setLazyInitialization:lazyInitialization];
    self.manager.applicationActive = ^BOOL {
        return active;
    };
    [Pushwoosh destroy];
    (void)[Pushwoosh sharedInstance];
    [self drainMainQueue];
}

- (void)setUserIdWithoutWaiting:(NSString *)userId completion:(void (^)(NSError *error))completion {
    [self prepareInAppManager];
    [[Pushwoosh configure] setUserId:userId completion:completion];
}

- (NSError *)setUserIdAndWait:(NSString *)userId {
    XCTestExpectation *done = [self expectationWithDescription:@"setUserId"];
    __block NSError *result;
    [self setUserIdWithoutWaiting:userId completion:^(NSError *error) {
        result = error;
        [done fulfill];
    }];
    [self waitForExpectations:@[done] timeout:5];
    return result;
}

- (void)drainMainQueue {
    XCTestExpectation *drained = [self expectationWithDescription:@"main queue"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    [self waitForExpectations:@[drained] timeout:5];
}

- (void)waitForFlag:(NSString *)key {
    __weak typeof(self) wSelf = self;
    NSPredicate *cached = [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
        return [wSelf.featureFlags flagForKey:key] != nil;
    }];
    [self waitForExpectations:@[ [[XCTNSPredicateExpectation alloc] initWithPredicate:cached object:nil] ] timeout:5];
}

- (void)logImpression:(NSString *)key {
    [self prepareInAppManager];
    [self.featureFlags logImpression:key];
}

- (void)logImpressionAndSettle:(NSString *)key {
    [self logImpression:key];
    [self drainMainQueue];
}

- (NSDictionary *)postedEventAt:(NSUInteger)index {
    return [self bodyOfRequest:_postedEvents[index]][@"request"];
}

- (void)completeHeldPostAt:(NSUInteger)index succeeded:(BOOL)succeeded {
    _heldPostEvents[index](succeeded);
}

- (void)assertJSONBoolean:(id)value equals:(BOOL)expected {
    XCTAssertTrue([value isKindOfClass:[NSNumber class]] && CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID(), @"%@ is not a JSON boolean", value);
    XCTAssertEqual([value boolValue], expected);
}

- (void)startSessionWithFlagsV1 {
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self post:UIApplicationDidBecomeActiveNotification];
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

- (void)startNewSessionAfter:(NSTimeInterval)background {
    [self post:UIApplicationDidEnterBackgroundNotification];
    _now += background;
    [self post:UIApplicationDidBecomeActiveNotification];
}

- (PWFeatureFlagsTestListener *)addListener {
    PWFeatureFlagsTestListener *listener = [[PWFeatureFlagsTestListener alloc] initWithCalls:_listenerCalls];
    [self.featureFlags addUpdateListener:listener];
    return listener;
}

- (void)refreshWithReplyFlags:(NSDictionary *)flags etag:(NSString *)etag {
    [self passThrottle];
    [self replyFlags:flags etag:etag];
    XCTAssertNil([self refreshAndWait]);
    [self drainMainQueue];
}

- (NSError *)refreshAndWaitWithManager:(PWFeatureFlagsManager *)manager {
    XCTestExpectation *done = [self expectationWithDescription:@"refresh"];
    __block NSError *result;
    [manager refreshWithCompletion:^(NSError *error) {
        result = error;
        [done fulfill];
    }];
    [self waitForExpectations:@[done] timeout:5];
    return result;
}

- (PWFeatureFlagsManager *)restartedManager {
    PWFeatureFlagsManager *restarted = [PWFeatureFlagsManager new];
    restarted.clock = self.manager.clock;
    return restarted;
}

- (NSError *)refreshAndWait {
    XCTestExpectation *done = [self expectationWithDescription:@"refresh"];
    __block NSError *result;
    [self.featureFlags refreshWithCompletion:^(NSError *error) {
        result = error;
        [done fulfill];
    }];
    [self waitForExpectations:@[done] timeout:5];
    return result;
}

- (NSDictionary *)flagsV1 {
    return @{ @"new_checkout": @{ @"enabled": @YES, @"rule_id": @"r_1", @"properties": @{ @"color": @"green" } } };
}

- (NSDictionary *)flagsV2 {
    return @{ @"new_checkout": @{ @"enabled": @NO, @"rule_id": @"", @"properties": @{ @"color": @"blue" } } };
}

- (void)cacheV1 {
    [self replyFlags:self.flagsV1 etag:@"e1"];
    XCTAssertNil([self refreshAndWait]);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

- (NSArray *)contractCases {
    NSString *path = [[NSBundle bundleForClass:self.class] pathForResource:@"feature_flags_contract" ofType:@"json"];
    XCTAssertNotNil(path);
    NSDictionary *fixture = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path] options:0 error:nil];
    return fixture[@"cases"];
}

- (NSDictionary *)wantOfContractCase:(NSString *)name {
    for (NSDictionary *contractCase in self.contractCases) {
        if ([contractCase[@"name"] isEqualToString:name]) {
            return contractCase[@"want"];
        }
    }
    XCTFail(@"no fixture case %@", name);
    return nil;
}

#pragma mark - Request

/// Verifies that refresh posts a flat body to the device API derived from the SDK base URL.
- (void)testRefreshSendsFlatBodyToDeviceApiOfBaseUrl {
    [self replyFlags:@{} etag:@""];

    XCTAssertNil([self refreshAndWait]);

    XCTAssertEqual(_sentRequests.count, 1);
    NSURLRequest *request = _sentRequests.firstObject;
    XCTAssertEqualObjects(request.URL.absoluteString, @"https://ffhost.example.com/api/v2/device-api/getFeatureFlags");
    XCTAssertEqualObjects(request.HTTPMethod, @"POST");
    NSDictionary *expectedBody = @{ @"application": kTestAppCode, @"hwid": [PWPreferences preferences].hwid };
    XCTAssertEqualObjects([self bodyOfRequest:request], expectedBody);
}

/// Verifies that flags go through a reverse proxy whose URL ends with json/1.3/.
- (void)testRefreshGoesThroughReverseProxy {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com/pw/json/1.3/" headers:@{ @"X-Proxy": @"1" }];
    [self replyFlags:@{} etag:@""];

    XCTAssertNil([self refreshAndWait]);

    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertEqualObjects(_sentRequests.firstObject.URL.absoluteString, @"https://proxy.example.com/pw/api/v2/device-api/getFeatureFlags");
    XCTAssertEqualObjects([_sentRequests.firstObject valueForHTTPHeaderField:@"X-Proxy"], @"1");
}

/// Verifies that a reverse proxy without json/1.3/ fails the refresh with code 0 and sends nothing past it.
- (void)testReverseProxyWithoutLegacyPathFailsWithoutRequest {
    [_requestManager setReverseProxyUrl:@"https://proxy.example.com/gateway/" headers:nil];

    NSError *error = [self refreshAndWait];

    XCTAssertEqualObjects(error.domain, PWFeatureFlagsErrorDomain);
    XCTAssertEqual(error.code, 0);
    XCTAssertEqual(_sentRequests.count, 0);
}

/// Verifies that a base URL without json/1.3/ falls back to the application host of the device API.
- (void)testBaseUrlWithoutLegacyPathFallsBackToApplicationHost {
    [[PWPreferences preferences] updateBaseUrl:@"https://custom.example.com/"];
    [self replyFlags:@{} etag:@""];

    XCTAssertNil([self refreshAndWait]);

    XCTAssertEqualObjects(_sentRequests.firstObject.URL.absoluteString, @"https://FFTST-00001.api.pushwoosh.com/api/v2/device-api/getFeatureFlags");
}

/// Verifies that falling back to the application host of the device API is logged as a warning naming that host.
- (void)testBaseUrlWithoutLegacyPathWarnsAboutFallbackHost {
    [[PWPreferences preferences] updateBaseUrl:@"https://custom.example.com/"];
    [self replyFlags:@{} etag:@""];
    _logMock = OCMClassMock([PushwooshLog class]);
    OCMExpect([_logMock pushwooshLog:PW_LL_WARN className:OCMOCK_ANY message:[OCMArg checkWithBlock:^BOOL(NSString *message) {
        return [message containsString:@"json/1.3/"] && [message containsString:@"https://FFTST-00001.api.pushwoosh.com/api/v2/device-api/"];
    }]]);

    XCTAssertNil([self refreshAndWait]);

    OCMVerifyAll(_logMock);
}

/// Verifies that with an application selected by the app the flags go to its host with its application code.
- (void)testSelectedApplicationReceivesFlagsRequest {
    XCTAssertTrue([[PWPreferences preferences] switchToApplicationWithAppCode:@"FFTST-00002" baseUrl:@"https://second.example.com/json/1.3/"]);
    [self replyFlags:self.flagsV1 etag:@"e1"];

    XCTAssertNil([self refreshAndWait]);

    NSURLRequest *request = _sentRequests.firstObject;
    XCTAssertEqualObjects(request.URL.absoluteString, @"https://second.example.com/api/v2/device-api/getFeatureFlags");
    XCTAssertEqualObjects([self bodyOfRequest:request][@"application"], @"FFTST-00002");
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that a reverse proxy set while a refresh waits for the SDK to be ready carries that refresh.
- (void)testReverseProxySetBeforeSdkReadyCarriesQueuedRefresh {
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [self replyFlags:@{} etag:@""];
    XCTestExpectation *done = [self expectationWithDescription:@"refresh"];
    [self.featureFlags refreshWithCompletion:^(NSError *error) {
        XCTAssertNil(error);
        [done fulfill];
    }];

    [_requestManager setReverseProxyUrl:@"https://proxy.example.com/pw/json/1.3/" headers:nil];
    [[PWSdkStateProvider sharedInstance] setReady];
    [self waitForExpectations:@[done] timeout:5];

    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertEqualObjects(_sentRequests.firstObject.URL.absoluteString, @"https://proxy.example.com/pw/api/v2/device-api/getFeatureFlags");
}

/// Verifies that the etag of a full response is sent with the next refresh.
- (void)testNextRefreshSendsEtag {
    [self cacheV1];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    [self passThrottle];

    XCTAssertNil([self refreshAndWait]);

    XCTAssertEqualObjects([self bodyOfRequest:_sentRequests[1]][@"etag"], @"e1");
}

/// Verifies that an empty etag (account without feature flags) is not sent and get returns nil.
- (void)testEmptyEtagIsNotSent {
    [self replyFlags:@{} etag:@""];
    [self replyFlags:@{} etag:@""];

    XCTAssertNil([self refreshAndWait]);
    [self passThrottle];
    XCTAssertNil([self refreshAndWait]);

    XCTAssertNil([self bodyOfRequest:_sentRequests[1]][@"etag"]);
    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
}

/// Verifies that the empty answer (plan without feature flags or suspended account) erases the cached flags without an error.
- (void)testEmptyAnswerErasesCachedFlags {
    [self cacheV1];
    [self replyFlags:@{} etag:@""];
    [self passThrottle];

    XCTAssertNil([self refreshAndWait]);

    XCTAssertEqualObjects([self bodyOfRequest:_sentRequests[1]][@"etag"], @"e1");
    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
    XCTAssertFalse([self.featureFlags isEnabled:@"new_checkout" defaultValue:NO]);
    XCTAssertNil([self.restartedManager flagForKey:@"new_checkout"]);
}

/// Verifies that base_url in the flags response does not move the host of other SDK requests.
- (void)testServerBaseUrlInFlagsResponseIsIgnored {
    NSDictionary *envelope = @{ @"status_code": @200, @"status_message": @"OK", @"base_url": @"https://moved.example.com/json/1.3/",
                                @"response": @{ @"flags": @{}, @"etag": @"", @"not_modified": @NO, @"partial": @NO } };
    NSData *data = [NSJSONSerialization dataWithJSONObject:envelope options:0 error:nil];
    [self replyStatus:200 body:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];

    XCTAssertNil([self refreshAndWait]);

    XCTAssertEqualObjects([PWPreferences preferences].baseUrl, kTestBaseUrl);
}

/// Verifies that a flags response without status_code does not reset the host of other SDK requests.
- (void)testFlagsResponseWithoutStatusCodeKeepsBaseUrl {
    [self replyStatus:404 body:@"{\"error\":\"not found\"}"];

    NSError *error = [self refreshAndWait];

    XCTAssertEqual(error.code, 404);
    XCTAssertEqualObjects([PWPreferences preferences].baseUrl, kTestBaseUrl);
}

#pragma mark - Cache

/// Verifies that a full response is readable through get, isEnabled and the property getters.
- (void)testFullResponseIsReadableThroughGetters {
    NSDictionary *want = [self wantOfContractCase:@"everyone rule at 100% enables the flag and applies overrides"];
    [self replyFlags:@{ @"new_checkout": want } etag:@"e1"];

    XCTAssertNil([self refreshAndWait]);

    PWFeatureFlag *flag = [self.featureFlags flagForKey:@"new_checkout"];
    XCTAssertEqualObjects(flag.key, @"new_checkout");
    XCTAssertTrue(flag.isEnabled);
    XCTAssertEqualObjects(flag.ruleId, @"r_00000001");
    XCTAssertEqualObjects([flag stringForProperty:@"color" defaultValue:@"x"], @"green");
    XCTAssertEqual([flag numberForProperty:@"limit" defaultValue:-1], 3);
    XCTAssertTrue([self.featureFlags isEnabled:@"new_checkout" defaultValue:NO]);
    XCTAssertNil([self.featureFlags flagForKey:@"absent"]);
    XCTAssertTrue([self.featureFlags isEnabled:@"absent" defaultValue:YES]);
}

/// Verifies that every case of the server contract fixture is read back as its want.
- (void)testEveryContractCaseIsReadBack {
    for (NSDictionary *contractCase in self.contractCases) {
        NSString *name = contractCase[@"name"];
        NSDictionary *want = contractCase[@"want"];
        [self replyFlags:@{ @"k": want } etag:@""];
        _now += kHour;

        XCTAssertNil([self refreshAndWait], @"%@", name);

        PWFeatureFlag *flag = [self.featureFlags flagForKey:@"k"];
        XCTAssertEqual(flag.isEnabled, [want[@"enabled"] boolValue], @"%@", name);
        XCTAssertEqualObjects(flag.ruleId, want[@"rule_id"], @"%@", name);
        [want[@"properties"] enumerateKeysAndObjectsUsingBlock:^(NSString *property, id value, BOOL *stop) {
            if ([value isKindOfClass:[NSString class]]) {
                XCTAssertEqualObjects([flag stringForProperty:property defaultValue:@"__default__"], value, @"%@", name);
            } else {
                XCTAssertEqual([flag numberForProperty:property defaultValue:-12345], [value doubleValue], @"%@", name);
            }
        }];
    }
}

/// Verifies that getters return the default for an absent property or another JSON type, a JSON boolean is not a number.
- (void)testPropertyGettersAreStrictAboutTypes {
    NSDictionary *properties = @{ @"s": @"3", @"n": @3, @"b": @YES, @"o": @{ @"a": @1 }, @"a": @[ @1, @2 ], @"z": [NSNull null] };
    [self replyFlags:@{ @"f": @{ @"enabled": @YES, @"rule_id": @"r", @"properties": properties } } etag:@"e1"];
    XCTAssertNil([self refreshAndWait]);

    PWFeatureFlag *flag = [self.featureFlags flagForKey:@"f"];

    XCTAssertEqual([flag numberForProperty:@"s" defaultValue:1.5], 1.5);
    XCTAssertEqualObjects([flag stringForProperty:@"n" defaultValue:@"d"], @"d");
    XCTAssertFalse([flag boolForProperty:@"n" defaultValue:NO]);
    XCTAssertEqual([flag numberForProperty:@"b" defaultValue:7], 7);
    XCTAssertTrue([flag boolForProperty:@"b" defaultValue:NO]);
    XCTAssertEqualObjects([flag stringForProperty:@"b" defaultValue:@"d"], @"d");
    XCTAssertEqualObjects([flag stringForProperty:@"z" defaultValue:@"d"], @"d");
    XCTAssertNil([flag stringForProperty:@"gone" defaultValue:nil]);
    XCTAssertEqualObjects([flag jsonObjectForProperty:@"o"], @{ @"a": @1 });
    XCTAssertEqualObjects([flag jsonArrayForProperty:@"a"], (@[ @1, @2 ]));
    XCTAssertNil([flag jsonObjectForProperty:@"a"]);
    XCTAssertNil([flag jsonArrayForProperty:@"o"]);
}

/// Verifies that not_modified keeps the flags and renews their age.
- (void)testNotModifiedKeepsFlagsAndRenewsAge {
    [self cacheV1];
    _now += 23 * kHour;
    [self replyFlags:@{} etag:@"e1" notModified:YES partial:NO];

    XCTAssertNil([self refreshAndWait]);
    _now += 2 * kHour;

    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that a partial response does not replace a valid cache and does not change the etag.
- (void)testPartialResponseDoesNotReplaceValidCache {
    [self cacheV1];
    [self replyFlags:self.flagsV2 etag:@"e2" notModified:NO partial:YES];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];

    [self passThrottle];
    XCTAssertNil([self refreshAndWait]);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);

    [self passThrottle];
    XCTAssertNil([self refreshAndWait]);
    XCTAssertEqualObjects([self bodyOfRequest:_sentRequests[2]][@"etag"], @"e1");
}

/// Verifies that a partial response without a cache is used for the session only and is not persisted.
- (void)testPartialResponseWithoutCacheIsNotPersisted {
    [self replyFlags:self.flagsV2 etag:@"e2" notModified:NO partial:YES];

    XCTAssertNil([self refreshAndWait]);

    XCTAssertFalse([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
    XCTAssertNotNil([self.featureFlags flagForKey:@"new_checkout"]);
    PWFeatureFlagsManager *restarted = [PWFeatureFlagsManager new];
    restarted.clock = [PWFeatureFlagsManager sharedManager].clock;
    XCTAssertNil([restarted flagForKey:@"new_checkout"]);
}

/// Verifies that a partial response over a session-only partial replaces it in memory, still without persisting or etag.
- (void)testPartialResponseOverPartialReplacesItForSessionOnly {
    [self replyFlags:self.flagsV2 etag:@"e2" notModified:NO partial:YES];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:NO partial:YES];
    [self replyFlags:self.flagsV1 etag:@"e1"];

    XCTAssertNil([self refreshAndWait]);
    XCTAssertFalse([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
    [self passThrottle];
    XCTAssertNil([self refreshAndWait]);

    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
    XCTAssertNil([self.restartedManager flagForKey:@"new_checkout"]);
    [self passThrottle];
    XCTAssertNil([self refreshAndWait]);
    XCTAssertNil([self bodyOfRequest:_sentRequests[1]][@"etag"]);
    XCTAssertNil([self bodyOfRequest:_sentRequests[2]][@"etag"]);
}

/// Verifies that a partial response over a cache older than 24 hours is used for the session only, without etag.
- (void)testPartialResponseOverStaleCacheIsNotPersisted {
    [self cacheV1];
    _now += 25 * kHour;
    [self replyFlags:self.flagsV2 etag:@"e2" notModified:NO partial:YES];
    [self replyFlags:self.flagsV2 etag:@"e2"];

    XCTAssertNil([self refreshAndWait]);

    XCTAssertFalse([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
    XCTAssertNotNil([self.featureFlags flagForKey:@"new_checkout"]);
    XCTAssertNil([self.restartedManager flagForKey:@"new_checkout"]);
    [self passThrottle];
    XCTAssertNil([self refreshAndWait]);
    XCTAssertNil([self bodyOfRequest:_sentRequests[2]][@"etag"]);
}

/// Verifies that a partial response over the cache of another user is used for the session only and keeps that cache.
- (void)testPartialResponseOverCacheOfAnotherUserIsNotPersisted {
    [self cacheV1];
    [PWPreferences preferences].userId = @"user-B";
    [self replyFlags:self.flagsV2 etag:@"e2" notModified:NO partial:YES];

    XCTAssertNil([self refreshAndWait]);

    XCTAssertNil([self bodyOfRequest:_sentRequests[1]][@"etag"]);
    XCTAssertFalse([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
    XCTAssertNotNil([self.featureFlags flagForKey:@"new_checkout"]);
    XCTAssertNil([self.restartedManager flagForKey:@"new_checkout"]);
    [PWPreferences preferences].userId = @"user-A";
    XCTAssertTrue([self.restartedManager flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that a partial response over a cache stored for another application code is used for the session only.
- (void)testPartialResponseOverCacheOfAnotherApplicationIsNotPersisted {
    [self cacheV1];
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"PWFeatureFlagsCache"];
    [PWPreferences preferences].appCode = @"FFTST-00002";
    [[NSUserDefaults standardUserDefaults] setObject:stored forKey:@"PWFeatureFlagsCache"];
    PWFeatureFlagsManager *otherApplication = self.restartedManager;
    [self replyFlags:self.flagsV2 etag:@"e2" notModified:NO partial:YES];

    XCTAssertNil([self refreshAndWaitWithManager:otherApplication]);

    NSDictionary *body = [self bodyOfRequest:_sentRequests.lastObject];
    XCTAssertEqualObjects(body[@"application"], @"FFTST-00002");
    XCTAssertNil(body[@"etag"]);
    XCTAssertFalse([otherApplication flagForKey:@"new_checkout"].isEnabled);
    XCTAssertNotNil([otherApplication flagForKey:@"new_checkout"]);
    XCTAssertNil([self.restartedManager flagForKey:@"new_checkout"]);
}

/// Verifies that a full response survives an app restart, etag included.
- (void)testFullResponseSurvivesRestart {
    [self cacheV1];

    PWFeatureFlagsManager *restarted = [PWFeatureFlagsManager new];
    restarted.clock = [PWFeatureFlagsManager sharedManager].clock;

    XCTAssertEqualObjects([restarted flagForKey:@"new_checkout"].ruleId, @"r_1");
}

/// Verifies that HTTP errors and offline keep the cache and report the HTTP status as the error code.
- (void)testErrorsKeepCacheAndReportHttpStatus {
    [self cacheV1];

    for (NSNumber *status in @[ @400, @401, @429, @500, @503 ]) {
        [self replyStatus:status.integerValue body:@"{\"status_code\":400,\"status_message\":\"failed\"}"];
        [self passThrottle];
        NSError *error = [self refreshAndWait];
        XCTAssertEqualObjects(error.domain, PWFeatureFlagsErrorDomain);
        XCTAssertEqual(error.code, status.integerValue);
        XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled, @"%@", status);
    }

    [self replyOffline];
    [self passThrottle];
    NSError *offline = [self refreshAndWait];
    XCTAssertEqualObjects(offline.domain, PWFeatureFlagsErrorDomain);
    XCTAssertEqual(offline.code, 0);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that a 401 with an empty body keeps the cache and reports 401.
- (void)testUnauthorizedWithEmptyBodyKeepsCache {
    [self cacheV1];
    [self replyStatus:401 body:@""];
    [self passThrottle];

    XCTAssertEqual([self refreshAndWait].code, 401);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that an HTTP 200 whose body cannot be used fails with code 200 and keeps the cache.
- (void)testUnusableResponseFailsWith200 {
    [self cacheV1];
    [self replyStatus:200 body:[self envelopeWithResponse:@{ @"flags": @"oops", @"etag": @"e9" }]];
    [self replyStatus:200 body:@"{\"status_code\":400,\"status_message\":\"bad request\"}"];

    [self passThrottle];
    XCTAssertEqual([self refreshAndWait].code, 200);
    [self passThrottle];
    XCTAssertEqual([self refreshAndWait].code, 200);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that a cache older than 24 hours is not returned.
- (void)testCacheOlderThan24HoursIsNotReturned {
    [self cacheV1];

    _now += 24 * kHour - 1;
    XCTAssertNotNil([self.featureFlags flagForKey:@"new_checkout"]);

    _now += 2;
    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
    XCTAssertFalse([self.featureFlags isEnabled:@"new_checkout" defaultValue:NO]);
}

/// Verifies that the cache of another user is not returned.
- (void)testCacheOfAnotherUserIsNotReturned {
    [self cacheV1];

    [PWPreferences preferences].userId = @"user-B";

    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
}

/// Verifies that not_modified on a cache older than 24 hours makes it valid again and calls the listener once.
- (void)testNotModifiedRevivesCacheOlderThan24HoursAndCallsListenerOnce {
    [self cacheV1];
    [self drainMainQueue];
    PWFeatureFlagsTestListener *listener = [self addListener];
    _now += 25 * kHour;
    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
    [self replyFlags:@{} etag:@"e1" notModified:YES partial:NO];

    XCTAssertNil([self refreshAndWait]);
    [self drainMainQueue];

    XCTAssertEqualObjects([self bodyOfRequest:_sentRequests.lastObject][@"etag"], @"e1");
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
    XCTAssertEqual(_listenerCalls.count, 1);
    XCTAssertNotNil(listener);
}

#pragma mark - Refresh

/// Verifies that a refresh made while a request is in flight joins it instead of sending another one.
- (void)testRefreshJoinsRequestInFlight {
    _holdReplies = YES;
    [self replyFlags:self.flagsV1 etag:@"e1"];
    XCTestExpectation *first = [self expectationWithDescription:@"first"];
    XCTestExpectation *second = [self expectationWithDescription:@"second"];

    [self.featureFlags refreshWithCompletion:^(NSError *error) {
        XCTAssertNil(error);
        [first fulfill];
    }];
    [self.featureFlags refreshWithCompletion:^(NSError *error) {
        XCTAssertNil(error);
        [second fulfill];
    }];
    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertEqual(_heldReplies.count, 1);
    for (dispatch_block_t deliver in _heldReplies) {
        deliver();
    }

    [self waitForExpectations:@[first, second] timeout:5];
    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that the refresh completion runs on the main thread when refresh is called off it.
- (void)testCompletionRunsOnMainThread {
    [self replyFlags:@{} etag:@""];
    XCTestExpectation *done = [self expectationWithDescription:@"refresh"];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [self.featureFlags refreshWithCompletion:^(NSError *error) {
            XCTAssertTrue([NSThread isMainThread]);
            [done fulfill];
        }];
    });

    [self waitForExpectations:@[done] timeout:5];
}

/// Verifies that a refresh made before the SDK is ready is sent once it is ready and completes on the main thread.
- (void)testRefreshBeforeSdkReadyIsSentAfterReadyAndCompletesOnMain {
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    XCTestExpectation *done = [self expectationWithDescription:@"refresh"];
    __block BOOL called = NO;
    __block BOOL onMain = NO;
    __block NSError *result = nil;

    [self.featureFlags refreshWithCompletion:^(NSError *error) {
        called = YES;
        onMain = [NSThread isMainThread];
        result = error;
        [done fulfill];
    }];
    [self drainMainQueue];
    XCTAssertFalse(called);
    XCTAssertEqual(_sentRequests.count, 0);

    [[PWSdkStateProvider sharedInstance] setReady];
    [self waitForExpectations:@[done] timeout:5];

    XCTAssertNil(result);
    XCTAssertTrue(onMain);
    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that stopped server communication fails the refresh with code 0 without a request and the next refresh works.
- (void)testStoppedServerCommunicationFailsRefreshWithoutRequest {
    [[PWManagerBridge shared] stopServerCommunication];
    _serverCommunicationStopped = YES;

    NSError *error = [self refreshAndWait];

    XCTAssertEqualObjects(error.domain, PWFeatureFlagsErrorDomain);
    XCTAssertEqual(error.code, 0);
    XCTAssertEqual(_sentRequests.count, 0);

    [[PWManagerBridge shared] startServerCommunication];
    _serverCommunicationStopped = NO;
    [self replyFlags:self.flagsV1 etag:@"e1"];
    XCTAssertNil([self refreshAndWait]);
    XCTAssertEqual(_sentRequests.count, 1);
}

#pragma mark - Foreground triggers

/// Verifies that the first foreground of the process refreshes the flags.
- (void)testFirstForegroundRefreshes {
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];

    [self post:UIApplicationDidBecomeActiveNotification];

    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that returning after 29 minutes in background is the same session and does not refresh.
- (void)testForegroundAfterShortBackgroundDoesNotRefresh {
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self post:UIApplicationDidBecomeActiveNotification];

    [self post:UIApplicationDidEnterBackgroundNotification];
    _now += 29 * kMinute;
    [self post:UIApplicationDidBecomeActiveNotification];

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that returning after 31 minutes in background starts a new session and refreshes.
- (void)testForegroundAfterLongBackgroundRefreshes {
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    [self post:UIApplicationDidBecomeActiveNotification];

    [self post:UIApplicationDidEnterBackgroundNotification];
    _now += 31 * kMinute;
    [self post:UIApplicationDidBecomeActiveNotification];

    XCTAssertEqual(_sentRequests.count, 2);
}

/// Verifies that exactly 30 minutes in background starts a new session and refreshes.
- (void)testForegroundAfterExactlyThirtyMinutesInBackgroundRefreshes {
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    [self post:UIApplicationDidBecomeActiveNotification];

    [self startNewSessionAfter:30 * kMinute];

    XCTAssertEqual(_sentRequests.count, 2);
}

/// Verifies that one second short of 30 minutes in background is the same session and does not refresh.
- (void)testForegroundOneSecondBeforeThirtyMinutesDoesNotRefresh {
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self post:UIApplicationDidBecomeActiveNotification];

    [self startNewSessionAfter:30 * kMinute - 1];
    [self drainMainQueue];

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that becoming active again without entering background does not refresh.
- (void)testActiveAfterInactiveWithoutBackgroundDoesNotRefresh {
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self post:UIApplicationDidBecomeActiveNotification];

    [self post:UIApplicationWillResignActiveNotification];
    _now += 40 * kMinute;
    [self post:UIApplicationDidBecomeActiveNotification];

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that the foreground timer waits for 60 minutes since the last request and then refreshes every 60 minutes.
- (void)testForegroundTimerRefreshesAnHourAfterLastRequest {
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    [self post:UIApplicationDidBecomeActiveNotification];
    XCTAssertEqualWithAccuracy(_scheduledDelays.lastObject.doubleValue, 60 * kMinute, 0.001);

    _now += 20 * kMinute;
    [self post:UIApplicationDidEnterBackgroundNotification];
    _now += 20 * kMinute;
    [self post:UIApplicationDidBecomeActiveNotification];
    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertEqualWithAccuracy(_scheduledDelays.lastObject.doubleValue, 20 * kMinute, 0.001);

    _now += 20 * kMinute;
    _scheduledTimers.lastObject();

    XCTAssertEqual(_sentRequests.count, 2);
    XCTAssertEqualWithAccuracy(_scheduledDelays.lastObject.doubleValue, 60 * kMinute, 0.001);
}

/// Verifies that the foreground timer keeps refreshing every 60 minutes over several hours in foreground.
- (void)testForegroundTimerRefreshesEveryHourOverSeveralHours {
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self post:UIApplicationDidBecomeActiveNotification];
    XCTAssertEqual(_sentRequests.count, 1);

    for (NSUInteger hour = 1; hour <= 4; hour++) {
        XCTAssertEqual(_scheduledTimers.count, hour, @"hour %lu", (unsigned long)hour);
        XCTAssertEqualWithAccuracy(_scheduledDelays.lastObject.doubleValue, 60 * kMinute, 0.001, @"hour %lu", (unsigned long)hour);
        [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
        _now += 60 * kMinute;
        _scheduledTimers.lastObject();
        [self drainMainQueue];

        XCTAssertEqual(_sentRequests.count, hour + 1, @"hour %lu", (unsigned long)hour);
        XCTAssertEqualObjects([self bodyOfRequest:_sentRequests.lastObject][@"etag"], @"e1");
    }
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that entering background cancels the foreground timer.
- (void)testBackgroundCancelsForegroundTimer {
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self post:UIApplicationDidBecomeActiveNotification];
    dispatch_block_t timer = _scheduledTimers.lastObject;
    XCTAssertNotNil(timer);

    [self post:UIApplicationDidEnterBackgroundNotification];
    _now += 2 * kHour;
    timer();

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that a foreground right after a manual refresh is throttled.
- (void)testFirstForegroundRightAfterRefreshIsThrottled {
    [self.manager start];
    [self cacheV1];

    _now += kMinute;
    [self post:UIApplicationDidBecomeActiveNotification];

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that an app extension never requests flags, neither on start nor on manual refresh.
- (void)testAppExtensionNeverRequestsFlags {
    self.manager.inAppExtension = YES;
    [self.manager start];

    [self post:UIApplicationDidBecomeActiveNotification];
    NSError *error = [self refreshAndWait];

    XCTAssertEqual(_sentRequests.count, 0);
    XCTAssertEqualObjects(error.domain, PWFeatureFlagsErrorDomain);
    XCTAssertEqual(error.code, 0);
}

/// Verifies that a repeated start keeps one set of foreground observers, so a foreground schedules one timer.
- (void)testRepeatedStartKeepsOneForegroundObserver {
    [self.manager start];
    [self.manager start];
    [self replyFlags:self.flagsV1 etag:@"e1"];

    [self post:UIApplicationDidBecomeActiveNotification];

    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertEqual(_scheduledTimers.count, 1);
}

#pragma mark - Lazy initialization

/// Verifies that with lazy initialization an SDK initialized in an active app starts the session with a refresh.
- (void)testLazyInitializationInActiveAppRefreshesOnSdkStart {
    [self replyFlags:self.flagsV1 etag:@"e1"];

    [self initializeSdkWithLazyInitialization:YES applicationActive:YES];

    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
    XCTAssertEqualWithAccuracy(_scheduledDelays.lastObject.doubleValue, 60 * kMinute, 0.001);
}

/// Verifies that with lazy initialization an SDK initialized before the app is active refreshes on the first foreground.
- (void)testLazyInitializationInInactiveAppRefreshesOnForeground {
    [self initializeSdkWithLazyInitialization:YES applicationActive:NO];
    XCTAssertEqual(_sentRequests.count, 0);

    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self post:UIApplicationDidBecomeActiveNotification];

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that with lazy initialization the foreground triggers keep working after the SDK start: 30 minutes in background is a new session.
- (void)testLazyInitializationStartsForegroundTriggers {
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    [self initializeSdkWithLazyInitialization:YES applicationActive:YES];

    [self startNewSessionAfter:30 * kMinute];

    XCTAssertEqual(_sentRequests.count, 2);
}

/// Verifies that initializing the SDK again with lazy initialization repeats neither the refresh nor the foreground observers and timer.
- (void)testRepeatedLazyInitializationStartsOnce {
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self initializeSdkWithLazyInitialization:YES applicationActive:YES];
    [self initializeSdkWithLazyInitialization:YES applicationActive:YES];

    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertEqual(_scheduledTimers.count, 1);

    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    [self startNewSessionAfter:30 * kMinute];

    XCTAssertEqual(_sentRequests.count, 2);
    XCTAssertEqual(_scheduledTimers.count, 2);
}

/// Verifies that without lazy initialization initializing the SDK leaves the start to the launch hook and sends nothing.
- (void)testSdkInitializationWithoutLazyInitializationDoesNotStartRefreshes {
    [self initializeSdkWithLazyInitialization:NO applicationActive:YES];

    [self post:UIApplicationDidBecomeActiveNotification];

    XCTAssertEqual(_sentRequests.count, 0);
}

#pragma mark - Throttle

/// Verifies that a manual refresh within 5 minutes of the last request succeeds from a valid cache without a request.
- (void)testRefreshWithinFiveMinutesIsThrottled {
    [self cacheV1];

    _now += 5 * kMinute - 1;

    XCTAssertNil([self refreshAndWait]);
    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that a manual refresh 5 minutes after the last request is sent.
- (void)testRefreshAfterFiveMinutesIsSent {
    [self cacheV1];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];

    _now += 5 * kMinute;

    XCTAssertNil([self refreshAndWait]);
    XCTAssertEqual(_sentRequests.count, 2);
}

/// Verifies that a refresh without a valid cache is not throttled.
- (void)testRefreshWithoutCacheIsNotThrottled {
    [self replyStatus:500 body:@""];
    [self replyFlags:self.flagsV1 etag:@"e1"];

    XCTAssertEqual([self refreshAndWait].code, 500);
    XCTAssertNil([self refreshAndWait]);

    XCTAssertEqual(_sentRequests.count, 2);
}

/// Verifies that an account without flags (empty flags, empty etag) is a valid cache for the throttle.
- (void)testEmptyFlagsResponseIsThrottled {
    [self replyFlags:@{} etag:@""];

    XCTAssertNil([self refreshAndWait]);
    XCTAssertNil([self refreshAndWait]);

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that the Info.plist debug key turns the throttle off.
- (void)testThrottleDisabledByInfoPlistKey {
    id configMock = OCMPartialMock([PWConfig config]);
    OCMStub([configMock featureFlagsThrottleDisabled]).andReturn(YES);
    [self cacheV1];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];

    XCTAssertNil([self refreshAndWait]);

    [configMock stopMocking];
    XCTAssertEqual(_sentRequests.count, 2);
}

#pragma mark - Registration

/// Verifies that a registration after a request sent without registration refreshes once past the throttle.
- (void)testRegistrationAfterUnregisteredRequestRefreshesOnce {
    [self cacheV1];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];

    [self.manager deviceRegistered];
    [self.manager deviceRegistered];

    XCTAssertEqual(_sentRequests.count, 2);
}

/// Verifies that a registration after a request sent with registration does not refresh.
- (void)testRegistrationAfterRegisteredRequestDoesNotRefresh {
    [self.manager deviceRegistered];
    [self cacheV1];
    [self passThrottle];

    [self.manager deviceRegistered];

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that a registration while an unregistered request is in flight sends one follow-up after it.
- (void)testRegistrationWhileInFlightSendsFollowUp {
    _holdReplies = YES;
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    [self.featureFlags refreshWithCompletion:nil];

    [self.manager deviceRegistered];
    XCTAssertEqual(_sentRequests.count, 1);
    dispatch_block_t first = _heldReplies.firstObject;
    first();

    [self waitForRequestCount:2];
    XCTAssertEqualObjects([self bodyOfRequest:_sentRequests[1]][@"etag"], @"e1");
}

/// Verifies that a registration skipped for the same token within the interval does not refresh the flags.
- (void)testSameTokenWithinRegistrationIntervalDoesNotRefresh {
    [self prepareDeviceRegistration];
    [self cacheV1];
    [PWPreferences preferences].pushToken = @"ff-test-token";
    [PWPreferences preferences].lastRegTime = [NSDate date];
    [PWPreferences preferences].lastStatusMask = 0;

    [[PWPushNotificationsManagerCommon new] sendDevTokenToServer:@"ff-test-token" triggerCallbacks:NO];
    [self drainMainQueue];

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that registering a VoIP token, a registerDevice outside the APNs path, does not refresh the flags.
- (void)testVoIPTokenRegistrationDoesNotRefresh {
    [self cacheV1];
    XCTestExpectation *registered = [self expectationWithDescription:@"registerDevice"];

    [_requestManager sendRequest:[PWFeatureFlagsTestVoIPRegistration new] completion:^(NSError *error) {
        XCTAssertNil(error);
        [registered fulfill];
    }];
    [self waitForExpectations:@[registered] timeout:5];
    [self drainMainQueue];

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that in an app extension neither a registration nor a user id change or rejection requests flags.
- (void)testAppExtensionRegistrationAndUserIdDoNotRequestFlags {
    self.manager.inAppExtension = YES;

    [self.manager deviceRegistered];
    XCTAssertNil([self setUserIdAndWait:@"user-B"]);
    _registerUserFails = YES;
    XCTAssertNotNil([self setUserIdAndWait:@"user-C"]);
    [self drainMainQueue];

    XCTAssertEqual(_sentRequests.count, 0);
}

/// Verifies that a successful device registration through the push manager refreshes the flags.
- (void)testDeviceRegistrationRefreshesFlags {
    [self prepareDeviceRegistration];
    [self cacheV1];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    [PWPreferences preferences].lastRegTime = nil;

    [[PWPushNotificationsManagerCommon new] sendDevTokenToServer:@"ff-test-token" triggerCallbacks:NO];

    [self waitForRequestCount:2];
}

#pragma mark - Active application

/// Verifies that an application change clears the cache and the next request goes without etag.
- (void)testApplicationChangeClearsCacheAndEtag {
    [self cacheV1];
    [self replyFlags:self.flagsV1 etag:@"e1"];

    [self postApplicationChanged:@{ kPWActiveApplicationChangedAppCodeChangedKey: @YES }];

    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
    XCTAssertNil([self refreshAndWait]);
    XCTAssertEqual(_sentRequests.count, 2);
    XCTAssertNil([self bodyOfRequest:_sentRequests[1]][@"etag"]);
}

/// Verifies that an application change notification without the flag clears the cache.
- (void)testApplicationChangeWithoutFlagClearsCache {
    [self cacheV1];

    [self postApplicationChanged:nil];

    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
}

/// Verifies that moving only the endpoint of the same application keeps the cache.
- (void)testEndpointOnlyChangeKeepsCache {
    [self cacheV1];

    [self postApplicationChanged:@{ kPWActiveApplicationChangedAppCodeChangedKey: @NO }];

    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that a response sent before an application change is dropped.
- (void)testResponseInFlightDuringApplicationChangeIsDropped {
    _holdReplies = YES;
    [self replyFlags:self.flagsV1 etag:@"e1"];
    XCTestExpectation *done = [self expectationWithDescription:@"refresh"];
    [self.featureFlags refreshWithCompletion:^(NSError *error) {
        [done fulfill];
    }];

    [self postApplicationChanged:@{ kPWActiveApplicationChangedAppCodeChangedKey: @YES }];
    dispatch_block_t deliver = _heldReplies.firstObject;
    deliver();
    [self waitForExpectations:@[done] timeout:5];

    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
}

/// Verifies that a cache stored for another application code is not returned after restart.
- (void)testCacheOfAnotherApplicationIsNotReturned {
    [self cacheV1];
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"PWFeatureFlagsCache"];
    XCTAssertNotNil(stored);

    [PWPreferences preferences].appCode = @"FFTST-00002";
    [[NSUserDefaults standardUserDefaults] setObject:stored forKey:@"PWFeatureFlagsCache"];
    PWFeatureFlagsManager *otherApplication = [PWFeatureFlagsManager new];
    otherApplication.clock = self.manager.clock;
    XCTAssertNil([otherApplication flagForKey:@"new_checkout"]);

    [PWPreferences preferences].appCode = kTestAppCode;
    [[NSUserDefaults standardUserDefaults] setObject:stored forKey:@"PWFeatureFlagsCache"];
    PWFeatureFlagsManager *sameApplication = [PWFeatureFlagsManager new];
    sameApplication.clock = self.manager.clock;
    XCTAssertTrue([sameApplication flagForKey:@"new_checkout"].isEnabled);
}

#pragma mark - User change

/// Verifies that a new user id clears the cache at once and refreshes past the throttle without etag.
- (void)testUserChangeClearsCacheAndRefreshesWithoutEtag {
    [self cacheV1];
    _holdReplies = YES;
    [self replyFlags:self.flagsV2 etag:@"e2"];

    XCTAssertNil([self setUserIdAndWait:@"user-B"]);

    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
    XCTAssertEqual(_sentRequests.count, 2);
    XCTAssertNil([self bodyOfRequest:_sentRequests[1]][@"etag"]);
    dispatch_block_t deliver = _heldReplies.firstObject;
    deliver();
    [self waitForFlag:@"new_checkout"];
    XCTAssertFalse([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that a user change drops the cache of the previous user instead of only hiding it.
- (void)testUserChangeDropsCacheOfPreviousUser {
    [self cacheV1];
    [self replyOffline];

    XCTAssertNil([self setUserIdAndWait:@"user-B"]);
    [self waitForRequestCount:2];
    [self drainMainQueue];

    [PWPreferences preferences].userId = @"user-A";
    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
}

/// Verifies that confirming the same user keeps the flags and revalidates them without etag.
- (void)testSameUserConfirmationRevalidatesWithoutEtag {
    [self cacheV1];
    _holdReplies = YES;
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [PWPreferences preferences].lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * kHour];

    XCTAssertNil([self setUserIdAndWait:@"user-A"]);

    XCTAssertEqual(_sentRequests.count, 2);
    XCTAssertNil([self bodyOfRequest:_sentRequests[1]][@"etag"]);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that the same user id within a day sends no registration and no flags request.
- (void)testSameUserWithinDayDoesNotRefresh {
    [self cacheV1];

    XCTAssertNil([self setUserIdAndWait:@"user-A"]);
    [self drainMainQueue];

    XCTAssertEqual(_sentRequests.count, 1);
}

/// Verifies that a rejected user id keeps the cache of the current user and sends no flags request.
- (void)testRejectedUserIdKeepsCacheWithoutRefresh {
    [self cacheV1];
    _registerUserFails = YES;

    XCTAssertNotNil([self setUserIdAndWait:@"user-B"]);
    [self drainMainQueue];

    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that a rejected user id clears flags fetched for it before the rejection and refreshes the restored user.
- (void)testRejectedUserIdAfterItsRefreshClearsAndRefreshes {
    [self cacheV1];
    _holdRegisterUser = YES;
    _registerUserFails = YES;
    XCTestExpectation *rejected = [self expectationWithDescription:@"setUserId"];
    [self setUserIdWithoutWaiting:@"user-B" completion:^(NSError *error) {
        [rejected fulfill];
    }];
    [self replyFlags:self.flagsV2 etag:@"e2"];
    [self passThrottle];
    XCTAssertNil([self refreshAndWait]);
    XCTAssertFalse([self.featureFlags flagForKey:@"new_checkout"].isEnabled);

    _holdReplies = YES;
    [self replyFlags:self.flagsV1 etag:@"e1"];
    dispatch_block_t reject = _heldRegisterUser.firstObject;
    reject();
    [self waitForExpectations:@[rejected] timeout:5];

    XCTAssertEqual(_sentRequests.count, 3);
    XCTAssertNil([self bodyOfRequest:_sentRequests[2]][@"etag"]);
    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
    dispatch_block_t deliver = _heldReplies.firstObject;
    deliver();
    [self waitForFlag:@"new_checkout"];
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that the legacy empty user id is the hwid user, not a user change: the cache stays and is revalidated.
- (void)testLegacyEmptyUserIdIsHwidAndNotUserChange {
    [PWPreferences preferences].userId = [PWPreferences preferences].hwid;
    [self cacheV1];
    _holdReplies = YES;
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [self prepareInAppManager];
    XCTestExpectation *done = [self expectationWithDescription:@"setUserId"];
    __block NSError *result = nil;

    [[PWManagerBridge shared].inAppManager setUserId:@"" completion:^(NSError *error) {
        result = error;
        [done fulfill];
    }];
    [self waitForExpectations:@[done] timeout:5];

    XCTAssertNil(result);
    XCTAssertEqualObjects([PWPreferences preferences].userId, @"");
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
    XCTAssertEqual(_sentRequests.count, 2);
    XCTAssertNil([self bodyOfRequest:_sentRequests[1]][@"etag"]);
}

/// Verifies that an empty user id through configure is ignored: no user change, no flags request, the cache stays.
- (void)testEmptyUserIdThroughConfigureIsIgnored {
    [self cacheV1];
    [self prepareInAppManager];

    [[Pushwoosh configure] setUserId:@""];
    [self drainMainQueue];
    [self drainMainQueue];

    XCTAssertEqualObjects([PWPreferences preferences].userId, @"user-A");
    XCTAssertEqual(_sentRequests.count, 1);
    XCTAssertTrue([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

/// Verifies that a response sent before a user change is not cached and a request without etag follows it.
- (void)testResponseInFlightDuringUserChangeIsNotCached {
    [self cacheV1];
    [self passThrottle];
    _holdReplies = YES;
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    [self replyFlags:self.flagsV2 etag:@"e2"];
    [self.featureFlags refreshWithCompletion:nil];

    XCTAssertNil([self setUserIdAndWait:@"user-B"]);
    XCTAssertEqual(_sentRequests.count, 2);
    dispatch_block_t first = _heldReplies.firstObject;
    first();

    [self waitForRequestCount:3];
    XCTAssertNil([self bodyOfRequest:_sentRequests[2]][@"etag"]);
    XCTAssertNil([self.featureFlags flagForKey:@"new_checkout"]);
    dispatch_block_t second = _heldReplies.lastObject;
    second();
    [self waitForFlag:@"new_checkout"];
    XCTAssertFalse([self.featureFlags flagForKey:@"new_checkout"].isEnabled);
}

#pragma mark - Update listeners

/// Verifies that a listener is called once on the main thread when a refresh brings new flags.
- (void)testListenerIsCalledOnMainThreadWhenFlagsChange {
    PWFeatureFlagsTestListener *listener = [self addListener];

    [self cacheV1];
    [self drainMainQueue];

    XCTAssertEqualObjects(_listenerCalls, @[ @YES ]);
    XCTAssertNotNil(listener);
}

/// Verifies that not modified, an identical full response and an error do not call the listener.
- (void)testListenerIsNotCalledWithoutVisibleChange {
    PWFeatureFlagsTestListener *listener = [self addListener];
    [self cacheV1];
    [self drainMainQueue];

    [self passThrottle];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    XCTAssertNil([self refreshAndWait]);
    [self refreshWithReplyFlags:self.flagsV1 etag:@"e9"];
    [self passThrottle];
    [self replyStatus:500 body:@""];
    XCTAssertNotNil([self refreshAndWait]);
    [self drainMainQueue];

    XCTAssertEqual(_listenerCalls.count, 1);
    XCTAssertNotNil(listener);
}

/// Verifies that a change of enabled, rule id, a property, a property type or the set of flags calls the listener.
- (void)testListenerIsCalledForEveryVisibleChange {
    PWFeatureFlagsTestListener *listener = [self addListener];
    [self cacheV1];

    [self refreshWithReplyFlags:@{ @"new_checkout": @{ @"enabled": @YES, @"rule_id": @"r_2", @"properties": @{ @"color": @"green" } } } etag:@"e2"];
    [self refreshWithReplyFlags:@{ @"new_checkout": @{ @"enabled": @YES, @"rule_id": @"r_2", @"properties": @{ @"color": @"red" } } } etag:@"e3"];
    [self refreshWithReplyFlags:@{ @"new_checkout": @{ @"enabled": @YES, @"rule_id": @"r_2", @"properties": @{ @"color": @YES } } } etag:@"e4"];
    [self refreshWithReplyFlags:@{ @"new_checkout": @{ @"enabled": @YES, @"rule_id": @"r_2", @"properties": @{ @"color": @1 } } } etag:@"e5"];
    [self refreshWithReplyFlags:@{ @"new_checkout": @{ @"enabled": @NO, @"rule_id": @"r_2", @"properties": @{ @"color": @1 } } } etag:@"e6"];
    [self refreshWithReplyFlags:@{} etag:@"e7"];

    XCTAssertEqual(_listenerCalls.count, 7);
    XCTAssertNotNil(listener);
}

/// Verifies that a listener added twice is called once and a removed listener is not called.
- (void)testListenerAddedTwiceIsCalledOnceAndRemovedIsNotCalled {
    PWFeatureFlagsTestListener *listener = [self addListener];
    [self.featureFlags addUpdateListener:listener];

    [self cacheV1];
    [self drainMainQueue];
    XCTAssertEqual(_listenerCalls.count, 1);

    [self.featureFlags removeUpdateListener:listener];
    [self.featureFlags removeUpdateListener:listener];
    [self refreshWithReplyFlags:self.flagsV2 etag:@"e2"];
    XCTAssertEqual(_listenerCalls.count, 1);
}

/// Verifies that a listener is held weakly and is not called after it was released.
- (void)testReleasedListenerIsNotCalled {
    @autoreleasepool {
        [self addListener];
    }

    [self cacheV1];
    [self drainMainQueue];

    XCTAssertEqual(_listenerCalls.count, 0);
}

/// Verifies that clearing the cache on a user change does not call the listener and the new user's flags do.
- (void)testUserChangeCallsListenerOnlyForNewFlags {
    PWFeatureFlagsTestListener *listener = [self addListener];
    [self cacheV1];
    [self drainMainQueue];
    [self replyOffline];

    XCTAssertNil([self setUserIdAndWait:@"user-B"]);
    [self waitForRequestCount:2];
    [self drainMainQueue];
    XCTAssertEqual(_listenerCalls.count, 1);

    [self refreshWithReplyFlags:self.flagsV1 etag:@"e1"];
    XCTAssertEqual(_listenerCalls.count, 2);
    XCTAssertNotNil(listener);
}

#pragma mark - Impression

/// Verifies that an impression is posted once with the flag key, rule id and a JSON boolean enabled.
- (void)testImpressionIsPostedOnceWithTypedAttributes {
    [self cacheV1];

    [self logImpressionAndSettle:@"new_checkout"];
    [self logImpressionAndSettle:@"new_checkout"];
    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 1);
    NSDictionary *posted = [self postedEventAt:0];
    XCTAssertEqualObjects(posted[@"event"], @"PW_FeatureFlagImpression");
    XCTAssertEqualObjects(posted[@"attributes"][@"flag_key"], @"new_checkout");
    XCTAssertEqualObjects(posted[@"attributes"][@"rule_id"], @"r_1");
    [self assertJSONBoolean:posted[@"attributes"][@"enabled"] equals:YES];
}

/// Verifies that an impression of a killed flag carries an empty rule id and enabled false.
- (void)testImpressionOfKilledFlagSendsEmptyRuleIdAndFalse {
    [self replyFlags:self.flagsV2 etag:@"e2"];
    XCTAssertNil([self refreshAndWait]);

    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 1);
    NSDictionary *attributes = [self postedEventAt:0][@"attributes"];
    XCTAssertEqualObjects(attributes[@"rule_id"], @"");
    [self assertJSONBoolean:attributes[@"enabled"] equals:NO];
}

/// Verifies that an impression of a flag missing from the cache is not posted.
- (void)testImpressionOfUncachedFlagIsNotPosted {
    [self logImpressionAndSettle:@"new_checkout"];
    [self cacheV1];
    [self logImpressionAndSettle:@"missing"];

    XCTAssertEqual(_postedEvents.count, 0);
}

/// Verifies that a changed flag value is a new impression within the same session.
- (void)testImpressionOfChangedFlagValueIsPostedAgain {
    [self cacheV1];
    [self logImpressionAndSettle:@"new_checkout"];
    [self refreshWithReplyFlags:self.flagsV2 etag:@"e2"];

    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 2);
}

/// Verifies that a new session after 30 minutes in background posts the impression again.
- (void)testImpressionInNewSessionIsPostedAgain {
    [self startSessionWithFlagsV1];
    [self logImpressionAndSettle:@"new_checkout"];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];

    [self startNewSessionAfter:30 * kMinute];
    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 2);
}

/// Verifies that neither the first foreground nor a short background starts a new impression session.
- (void)testImpressionAfterFirstForegroundAndShortBackgroundIsNotPostedAgain {
    [self cacheV1];
    [self logImpressionAndSettle:@"new_checkout"];
    [self.manager start];
    [self post:UIApplicationDidBecomeActiveNotification];
    [self logImpressionAndSettle:@"new_checkout"];

    [self startNewSessionAfter:29 * kMinute];
    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 1);
}

/// Verifies that a user change posts the impression again for the new user's flags.
- (void)testImpressionAfterUserChangeIsPostedAgain {
    [self cacheV1];
    [self logImpressionAndSettle:@"new_checkout"];
    [self replyFlags:self.flagsV1 etag:@"e1"];

    XCTAssertNil([self setUserIdAndWait:@"user-B"]);
    [self waitForFlag:@"new_checkout"];
    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 2);
}

/// Verifies that confirming the same user keeps the impression logged for this session.
- (void)testImpressionAfterSameUserConfirmationIsNotPostedAgain {
    [self cacheV1];
    [self logImpressionAndSettle:@"new_checkout"];
    [self replyFlags:self.flagsV1 etag:@"e1"];
    [PWPreferences preferences].lastRegisterUserDate = [NSDate dateWithTimeIntervalSinceNow:-2 * 24 * kHour];

    XCTAssertNil([self setUserIdAndWait:@"user-A"]);
    [self waitForRequestCount:2];
    [self drainMainQueue];
    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 1);
}

/// Verifies that a rejected user id whose flags were already fetched posts the impression again for the restored user.
- (void)testImpressionAfterRejectedUserIdIsPostedAgain {
    [self cacheV1];
    _holdRegisterUser = YES;
    _registerUserFails = YES;
    XCTestExpectation *rejected = [self expectationWithDescription:@"setUserId"];
    [self setUserIdWithoutWaiting:@"user-B" completion:^(NSError *error) {
        [rejected fulfill];
    }];
    [self refreshWithReplyFlags:self.flagsV1 etag:@"e1"];
    [self logImpressionAndSettle:@"new_checkout"];
    [self replyFlags:self.flagsV1 etag:@"e1"];

    dispatch_block_t reject = _heldRegisterUser.firstObject;
    reject();
    [self waitForExpectations:@[rejected] timeout:5];
    [self waitForFlag:@"new_checkout"];
    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 2);
}

/// Verifies that an application change posts the impression again.
- (void)testImpressionAfterApplicationChangeIsPostedAgain {
    [self cacheV1];
    [self logImpressionAndSettle:@"new_checkout"];

    [self postApplicationChanged:@{ kPWActiveApplicationChangedAppCodeChangedKey: @YES }];
    [self cacheV1];
    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 2);
}

/// Verifies that a failed impression is posted again by the next call and a delivered one is not.
- (void)testFailedImpressionIsPostedAgainByNextCall {
    [self cacheV1];
    _postEventFails = YES;
    [self logImpressionAndSettle:@"new_checkout"];

    _postEventFails = NO;
    [self logImpressionAndSettle:@"new_checkout"];
    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 2);
}

/// Verifies that calls made while the impression is being posted send nothing more.
- (void)testImpressionCallsWhilePostInFlightPostOnce {
    [self cacheV1];
    _holdPostEvents = YES;

    [self logImpressionAndSettle:@"new_checkout"];
    [self logImpressionAndSettle:@"new_checkout"];
    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 1);
}

/// Verifies that impressions logged before the SDK is initialized and ready post exactly one event once it is ready.
- (void)testImpressionsBeforeSdkReadyArePostedOnceAfterReady {
    [self cacheV1];
    [self prepareInAppManager];
    [[PWSdkStateProvider sharedInstance] resetForTesting];
    [PWManagerBridge shared].inAppManager = nil;

    [self.featureFlags logImpression:@"new_checkout"];
    [self.featureFlags logImpression:@"new_checkout"];
    [self drainMainQueue];
    XCTAssertEqual(_postedEvents.count, 0);

    [PWManagerBridge shared].inAppManager = _inAppManagerMock;
    [[PWSdkStateProvider sharedInstance] setReady];
    [self waitForPostedEventCount:1];
    [self drainMainQueue];
    [self drainMainQueue];

    XCTAssertEqual(_postedEvents.count, 1);
}

/// Verifies that a post from the previous session finishing late does not mark the impression of the new session.
- (void)testImpressionPostedAcrossNewSessionDoesNotConsumeNewSession {
    [self startSessionWithFlagsV1];
    _holdPostEvents = YES;
    [self logImpressionAndSettle:@"new_checkout"];
    [self replyFlags:self.flagsV1 etag:@"e1" notModified:YES partial:NO];
    [self startNewSessionAfter:30 * kMinute];
    [self logImpressionAndSettle:@"new_checkout"];
    XCTAssertEqual(_postedEvents.count, 2);

    [self completeHeldPostAt:0 succeeded:YES];
    [self completeHeldPostAt:1 succeeded:NO];
    [self drainMainQueue];
    [self logImpressionAndSettle:@"new_checkout"];

    XCTAssertEqual(_postedEvents.count, 3);
}

@end
