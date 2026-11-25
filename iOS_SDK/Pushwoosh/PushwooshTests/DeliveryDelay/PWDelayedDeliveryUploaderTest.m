//
//  PWDelayedDeliveryUploaderTest.m
//  PushwooshTests
//
//  Created by André Kis
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#import "PWDeliveryDelayTestSeams.h"
#import "PWDelayedUploadCapture.h"
#import "PWPushRuntime.ios.h"
#import "PushwooshFramework.h"
#import "Pushwoosh+Internal.h"
#import "PWConfig.h"
#import "PWFeatureFlagsManager.h"

#if TARGET_OS_IOS

static NSString *const kExtensionSessionIdentifier = @"com.pushwoosh.nse.delayed-delivery";

@interface PWDelayedDeliveryUploaderTest : XCTestCase

@property (nonatomic) PWDelayedUploadCapture *upload;
@property (nonatomic) NSURL *containerURL;
@property (nonatomic) NSURL *bodyFileURL;
@property (nonatomic) PWDelayedDeliveryUploader *uploader;

@end

@implementation PWDelayedDeliveryUploaderTest

- (void)setUp {
    [super setUp];
    _containerURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
    [[NSFileManager defaultManager] createDirectoryAtURL:_containerURL withIntermediateDirectories:YES attributes:nil error:nil];

    _upload = [PWDelayedUploadCapture new];
    OCMStub([_upload.uploaderMock containerURLForAppGroup:@"group.test"]).andReturn(_containerURL);
    OCMStub([_upload.uploaderMock containerURLForAppGroup:@"group.missing"]).andReturn(nil);
    OCMStub([_upload.sessionMock configuration]).andReturn([PWDelayedDeliveryUploader sessionConfigurationWithIdentifier:kExtensionSessionIdentifier appGroupsName:@"group.test"]);

    NSURL *bodyDirectory = [_containerURL URLByAppendingPathComponent:@"PushwooshDeliveryEvents"];
    [[NSFileManager defaultManager] createDirectoryAtURL:bodyDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    _bodyFileURL = [bodyDirectory URLByAppendingPathComponent:@"body-1"];
    [[@"{\"request\":{\"hash\":\"h1\"}}" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:_bodyFileURL atomically:YES];

    _uploader = [PWDelayedDeliveryUploader new];
    OCMStub([_upload.uploaderMock sharedUploader]).andReturn(_uploader);
}

- (void)tearDown {
    [_upload stopMocking];
    [[NSFileManager defaultManager] removeItemAtURL:_containerURL error:nil];
    [super tearDown];
}

- (NSURLRequest *)deliveryRequest {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://proxy.example.com/messageDeliveryEvent"]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = [@"{\"request\":{\"hash\":\"h1\"}}" dataUsingEncoding:NSUTF8StringEncoding];
    [request setValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"Token t" forHTTPHeaderField:@"Authorization"];
    [request setValue:@"v" forHTTPHeaderField:@"X-Proxy"];
    return request;
}

- (id)sessionMockWithIdentifier:(NSString *)identifier {
    id session = OCMClassMock([NSURLSession class]);
    NSURLSessionConfiguration *configuration = [PWDelayedDeliveryUploader sessionConfigurationWithIdentifier:identifier appGroupsName:@"group.test"];
    OCMStub([session configuration]).andReturn(configuration);
    return session;
}

- (id)finishedTaskOfAttempt:(NSUInteger)attempt statusCode:(NSInteger)statusCode {
    NSMutableURLRequest *request = [[self deliveryRequest] mutableCopy];
    request.HTTPBody = nil;

    id task = OCMClassMock([NSURLSessionUploadTask class]);
    OCMStub([task taskDescription]).andReturn(([NSString stringWithFormat:@"%lu body-1", (unsigned long)attempt]));
    OCMStub([task originalRequest]).andReturn(request);
    if (statusCode > 0) {
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:statusCode HTTPVersion:@"HTTP/1.1" headerFields:nil];
        OCMStub([task response]).andReturn(response);
    }
    return task;
}

- (NSError *)noConnectionError {
    return [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil];
}

/// Verifies the upload task carries the request's URL, method and headers, uploads its body from a file, and starts no earlier than the delay.
- (void)testScheduleUploadsBodyWithSameHeadersAfterDelay {
    NSURLRequest *request = [self deliveryRequest];

    NSDate *before = [NSDate date];
    BOOL scheduled = [PWDelayedDeliveryUploader scheduleRequest:request afterDelay:42 appGroupsName:@"group.test"];
    NSDate *after = [NSDate date];

    XCTAssertTrue(scheduled);
    XCTAssertEqualObjects(_upload.request.URL, request.URL);
    XCTAssertEqualObjects(_upload.request.HTTPMethod, @"POST");
    XCTAssertEqualObjects(_upload.request.allHTTPHeaderFields, request.allHTTPHeaderFields);
    XCTAssertNil(_upload.request.HTTPBody);
    XCTAssertEqualObjects(_upload.body, request.HTTPBody);
    XCTAssertGreaterThanOrEqual([_upload.earliestBeginDate timeIntervalSinceDate:before], 42);
    XCTAssertLessThanOrEqual([_upload.earliestBeginDate timeIntervalSinceDate:after], 42);
    XCTAssertEqualObjects(_upload.taskDescription, ([NSString stringWithFormat:@"1 %@", _upload.fileURL.lastPathComponent]));
    OCMVerify([_upload.taskMock resume]);
}

/// Verifies bodies older than a day are removed on the next scheduling, while the body just staged and a recent one stay for their tasks.
- (void)testScheduleRemovesBodiesOlderThanADay {
    NSURL *directory = [_containerURL URLByAppendingPathComponent:@"PushwooshDeliveryEvents"];
    NSURL *stale = [directory URLByAppendingPathComponent:@"stale"];
    NSURL *recent = [directory URLByAppendingPathComponent:@"recent"];
    [[NSData data] writeToURL:stale atomically:YES];
    [[NSData data] writeToURL:recent atomically:YES];
    [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: [NSDate dateWithTimeIntervalSinceNow:-25 * 60 * 60]} ofItemAtPath:stale.path error:nil];
    [[NSFileManager defaultManager] setAttributes:@{NSFileModificationDate: [NSDate dateWithTimeIntervalSinceNow:-23 * 60 * 60]} ofItemAtPath:recent.path error:nil];

    [PWDelayedDeliveryUploader scheduleRequest:[self deliveryRequest] afterDelay:1 appGroupsName:@"group.test"];

    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:stale.path]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:recent.path]);
    XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:_upload.fileURL.path]);
    XCTAssertEqualObjects(_upload.fileURL.URLByDeletingLastPathComponent.lastPathComponent, @"PushwooshDeliveryEvents");
}

/// Verifies nothing is scheduled when the App Group container cannot be opened.
- (void)testScheduleWithoutContainerSchedulesNothing {
    XCTAssertFalse([PWDelayedDeliveryUploader scheduleRequest:[self deliveryRequest] afterDelay:1 appGroupsName:@"group.missing"]);
    XCTAssertNil(_upload.fileURL);
}

/// Verifies the background session shares the App Group container and wakes the app with the outcome once the extension is gone.
- (void)testSessionConfigurationSharesAppGroupContainerAndWakesApp {
    NSURLSessionConfiguration *configuration = [PWDelayedDeliveryUploader sessionConfigurationWithIdentifier:kExtensionSessionIdentifier appGroupsName:@"group.test"];

    XCTAssertEqualObjects(configuration.sharedContainerIdentifier, @"group.test");
    XCTAssertTrue(configuration.sessionSendsLaunchEvents);
}

/// Verifies no response and HTTP 408, 429, 500, 502, 503, 504 send the same body again with the same request and the next attempt number.
- (void)testTransientFailureSendsBodyAgain {
    NSArray<NSNumber *> *statusCodes = @[@0, @408, @429, @500, @502, @503, @504];

    for (NSNumber *statusCode in statusCodes) {
        [_upload reset];
        id task = [self finishedTaskOfAttempt:1 statusCode:statusCode.integerValue];

        [_uploader URLSession:_upload.sessionMock task:task didCompleteWithError:statusCode.integerValue == 0 ? [self noConnectionError] : nil];

        XCTAssertEqualObjects(_upload.fileURL, _bodyFileURL, @"HTTP %@", statusCode);
        XCTAssertEqualObjects(_upload.request.URL, [self deliveryRequest].URL, @"HTTP %@", statusCode);
        XCTAssertEqualObjects(_upload.request.allHTTPHeaderFields, [self deliveryRequest].allHTTPHeaderFields, @"HTTP %@", statusCode);
        XCTAssertEqualObjects(_upload.taskDescription, @"2 body-1", @"HTTP %@", statusCode);
        XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:_bodyFileURL.path], @"HTTP %@", statusCode);
    }
}

/// Verifies any other answer ends the delivery: nothing is sent again and the body file is removed.
- (void)testOtherAnswerRemovesBodyWithoutRetry {
    NSArray<NSNumber *> *statusCodes = @[@200, @400, @401, @404, @501];

    for (NSNumber *statusCode in statusCodes) {
        [[@"body" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:_bodyFileURL atomically:YES];

        [_uploader URLSession:_upload.sessionMock task:[self finishedTaskOfAttempt:1 statusCode:statusCode.integerValue] didCompleteWithError:nil];

        XCTAssertNil(_upload.fileURL, @"HTTP %@", statusCode);
        XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:_bodyFileURL.path], @"HTTP %@", statusCode);
    }
}

/// Verifies the next attempt starts 10, 20, 30 and 40 s after attempts 1 to 4 fail.
- (void)testRetryDelayGrowsByTenSecondsPerAttempt {
    for (NSUInteger attempt = 1; attempt <= 4; attempt++) {
        NSDate *before = [NSDate date];
        [_uploader URLSession:_upload.sessionMock task:[self finishedTaskOfAttempt:attempt statusCode:500] didCompleteWithError:nil];
        NSDate *after = [NSDate date];

        XCTAssertGreaterThanOrEqual([_upload.earliestBeginDate timeIntervalSinceDate:before], 10.0 * attempt);
        XCTAssertLessThanOrEqual([_upload.earliestBeginDate timeIntervalSinceDate:after], 10.0 * attempt);
        XCTAssertEqualObjects(_upload.taskDescription, ([NSString stringWithFormat:@"%lu body-1", (unsigned long)attempt + 1]));
    }
}

/// Verifies a failed fifth attempt is the last one: nothing is sent again and the body file is removed.
- (void)testFifthFailedAttemptGivesUpAndRemovesBody {
    [_uploader URLSession:_upload.sessionMock task:[self finishedTaskOfAttempt:5 statusCode:503] didCompleteWithError:nil];

    XCTAssertNil(_upload.fileURL);
    XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:_bodyFileURL.path]);
}

/// Verifies the app sends a failed attempt again in its own session, not in the extension's session it took the events of.
- (void)testAppSendsAgainInItsOwnSessionNotInExtensionSession {
    id extensionSession = [self sessionMockWithIdentifier:kExtensionSessionIdentifier];
    OCMStub([_upload.uploaderMock sessionWithIdentifier:kExtensionSessionIdentifier appGroupsName:OCMOCK_ANY]).andReturn(extensionSession);
    OCMStub([_upload.uploaderMock sessionWithIdentifier:OCMOCK_ANY appGroupsName:OCMOCK_ANY]).andReturn(_upload.sessionMock);
    OCMReject([extensionSession uploadTaskWithRequest:OCMOCK_ANY fromFile:OCMOCK_ANY]);

    XCTAssertTrue([PWDelayedDeliveryUploader handleEventsForBackgroundURLSession:kExtensionSessionIdentifier appGroupsName:@"group.test" completionHandler:^{}]);
    [_uploader URLSession:extensionSession task:[self finishedTaskOfAttempt:1 statusCode:502] didCompleteWithError:nil];

    XCTAssertEqualObjects(_upload.fileURL, _bodyFileURL);
    XCTAssertEqualObjects(_upload.taskDescription, @"2 body-1");
}

/// Verifies the app calls the system completion handler on the main queue once the events are handled, and closes the extension's session.
- (void)testFinishedEventsCallCompletionHandlerOnMainAndCloseExtensionSession {
    id extensionSession = [self sessionMockWithIdentifier:kExtensionSessionIdentifier];
    OCMStub([_upload.uploaderMock sessionWithIdentifier:OCMOCK_ANY appGroupsName:OCMOCK_ANY]).andReturn(extensionSession);
    XCTestExpectation *completed = [self expectationWithDescription:@"completion handler"];

    [PWDelayedDeliveryUploader handleEventsForBackgroundURLSession:kExtensionSessionIdentifier appGroupsName:@"group.test" completionHandler:^{
        XCTAssertTrue([NSThread isMainThread]);
        [completed fulfill];
    }];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        [self.uploader URLSessionDidFinishEventsForBackgroundURLSession:extensionSession];
    });

    [self waitForExpectations:@[completed] timeout:5];
    OCMVerify([extensionSession finishTasksAndInvalidate]);
}

/// Verifies events of a session the SDK does not own are left to the app and its completion handler untouched.
- (void)testForeignSessionEventsAreLeftToApp {
    __block BOOL called = NO;

    BOOL taken = [PWDelayedDeliveryUploader handleEventsForBackgroundURLSession:@"com.example.downloads" appGroupsName:@"group.test" completionHandler:^{
        called = YES;
    }];

    XCTAssertFalse(taken);
    XCTAssertFalse(called);
}

@end

typedef void (*PWEventsHookIMP)(id, SEL, id, NSString *, void (^)(void));

@interface PWConfig (BackgroundSessionEventsHookTest)
- (void)setLazyInitialization:(BOOL)lazyInitialization;
@end

static NSMutableArray<NSString *> *pw_events_appCalls;

static void pw_events_appHandler(id self, SEL _cmd, id application, NSString *identifier, void (^completionHandler)(void)) {
    [pw_events_appCalls addObject:identifier];
}

static SEL pw_events_selector(void) {
    return @selector(application:handleEventsForBackgroundURLSession:completionHandler:);
}

/// A fresh name per call: a hooked class stays hooked for the rest of the process.
static Class pw_events_makeDelegateClass(BOOL withHandler) {
    NSString *name = [NSString stringWithFormat:@"PWEventsHookDelegate_%u", arc4random()];
    Class cls = objc_allocateClassPair([NSObject class], name.UTF8String, 0);
    if (withHandler) {
        class_addMethod(cls, pw_events_selector(), (IMP)pw_events_appHandler, "v@:@@@?");
    }
    objc_registerClassPair(cls);
    return cls;
}

@interface PWBackgroundSessionEventsHookTest : XCTestCase

@property (nonatomic) id uploaderMock;

@end

@implementation PWBackgroundSessionEventsHookTest

- (void)setUp {
    [super setUp];
    pw_events_appCalls = [NSMutableArray new];
    _uploaderMock = OCMClassMock([PWDelayedDeliveryUploader class]);
    OCMStub([_uploaderMock handleEventsForBackgroundURLSession:kExtensionSessionIdentifier appGroupsName:OCMOCK_ANY completionHandler:OCMOCK_ANY]).andReturn(YES);
}

- (void)tearDown {
    [_uploaderMock stopMocking];
    [super tearDown];
}

- (void)deliverEventsOfSession:(NSString *)identifier to:(id)delegate {
    ((PWEventsHookIMP)objc_msgSend)(delegate, pw_events_selector(), nil, identifier, ^{});
}

/// Verifies the app's own handler still gets events of its sessions, and not those of the delivery session the SDK takes.
- (void)testAppHandlerGetsOnlyForeignSessions {
    Class delegateClass = pw_events_makeDelegateClass(YES);
    [PWPushRuntime swizzleBackgroundSessionEventsHandlerForDelegateClass:delegateClass];
    id delegate = [delegateClass new];

    [self deliverEventsOfSession:@"com.example.downloads" to:delegate];
    [self deliverEventsOfSession:kExtensionSessionIdentifier to:delegate];

    XCTAssertEqualObjects(pw_events_appCalls, @[@"com.example.downloads"]);
}

/// Verifies an app delegate without its own handler starts answering, so the system hands the delivery session's events to the SDK.
- (void)testDelegateWithoutHandlerGetsOne {
    Class delegateClass = pw_events_makeDelegateClass(NO);

    [PWPushRuntime swizzleBackgroundSessionEventsHandlerForDelegateClass:delegateClass];
    id delegate = [delegateClass new];
    [self deliverEventsOfSession:kExtensionSessionIdentifier to:delegate];

    XCTAssertTrue([delegate respondsToSelector:pw_events_selector()]);
    OCMVerify([_uploaderMock handleEventsForBackgroundURLSession:kExtensionSessionIdentifier appGroupsName:OCMOCK_ANY completionHandler:OCMOCK_ANY]);
}

/// Verifies a repeated install on the same class keeps one hook, so the app's handler is called once.
- (void)testRepeatedInstallCallsAppHandlerOnce {
    Class delegateClass = pw_events_makeDelegateClass(YES);
    [PWPushRuntime swizzleBackgroundSessionEventsHandlerForDelegateClass:delegateClass];
    [PWPushRuntime swizzleBackgroundSessionEventsHandlerForDelegateClass:delegateClass];

    [self deliverEventsOfSession:@"com.example.downloads" to:[delegateClass new]];

    XCTAssertEqualObjects(pw_events_appCalls, @[@"com.example.downloads"]);
}

/// Verifies that with lazy initialization the SDK start hooks the app delegate, so the delivery session's events reach the SDK.
- (void)testLazyInitializationHooksAppDelegateOnSdkStart {
    id delegate = [pw_events_makeDelegateClass(YES) new];
    id application = OCMClassMock([UIApplication class]);
    OCMStub([application sharedApplication]).andReturn(application);
    OCMStub([application delegate]).andReturn(delegate);
    id featureFlags = OCMPartialMock([PWFeatureFlagsManager sharedManager]);
    OCMStub([featureFlags startAfterLaunch]);
    BOOL savedLazyInitialization = [PWConfig config].lazyInitialization;
    [[PWConfig config] setLazyInitialization:YES];

    [Pushwoosh destroy];
    (void)[Pushwoosh pw_sharedInstance];

    [[PWConfig config] setLazyInitialization:savedLazyInitialization];
    [featureFlags stopMocking];
    [application stopMocking];

    [self deliverEventsOfSession:kExtensionSessionIdentifier to:delegate];
    [self deliverEventsOfSession:@"com.example.downloads" to:delegate];

    XCTAssertEqualObjects(pw_events_appCalls, @[@"com.example.downloads"]);
    OCMVerify([_uploaderMock handleEventsForBackgroundURLSession:kExtensionSessionIdentifier appGroupsName:OCMOCK_ANY completionHandler:OCMOCK_ANY]);
}

@end

#endif
