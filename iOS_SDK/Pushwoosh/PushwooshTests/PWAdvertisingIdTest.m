
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PushwooshConfig.h"
#import "PWPreferences.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"
#import "PWSetAdvertisingIdRequest.h"
#import "PWServerCommunicationManager.h"
#import "PWConfig.h"
#import "PWSdkStateProvider.h"
#import <PushwooshCore/PWManagerBridge.h>

@interface PWPreferences (AdvertisingTest)

- (void)resetApplicationSetting;

@end

@interface PWSdkStateProvider (AdvertisingTest)

- (void)resetForTesting;

@end

static NSString *const kTestKeyAdvertisingId = @"PWAdvertisingId";

@interface PWAdvertisingIdTest : XCTestCase

@end

@implementation PWAdvertisingIdTest

- (void)setUp {
    [super setUp];
    [[PWPreferences preferences] setAdvertisingId:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kTestKeyAdvertisingId];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)tearDown {
    [[PWPreferences preferences] setAdvertisingId:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kTestKeyAdvertisingId];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [super tearDown];
}

#pragma mark - PWPreferences Tests

/// Verifies that advertisingId is persisted in NSUserDefaults.
- (void)testSetAdvertisingId_persistsToUserDefaults {
    [[PWPreferences preferences] setAdvertisingId:@"test-idfa-123"];

    NSString *stored = [[NSUserDefaults standardUserDefaults] objectForKey:kTestKeyAdvertisingId];
    XCTAssertEqualObjects(stored, @"test-idfa-123");
}

/// Verifies that setting nil removes advertisingId from NSUserDefaults.
- (void)testSetAdvertisingIdNil_removesFromUserDefaults {
    [[PWPreferences preferences] setAdvertisingId:@"test-idfa-123"];
    [[PWPreferences preferences] setAdvertisingId:nil];

    NSString *stored = [[NSUserDefaults standardUserDefaults] objectForKey:kTestKeyAdvertisingId];
    XCTAssertNil(stored);
    XCTAssertNil([[PWPreferences preferences] advertisingId]);
}

/// Verifies that resetApplicationSetting clears advertisingId in memory and on disk.
- (void)testResetApplicationSetting_clearsAdvertisingId {
    [[PWPreferences preferences] setAdvertisingId:@"will-be-cleared"];
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:kTestKeyAdvertisingId], @"will-be-cleared");

    [[PWPreferences preferences] resetApplicationSetting];

    XCTAssertNil([[PWPreferences preferences] advertisingId]);
    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:kTestKeyAdvertisingId]);
}

#pragma mark - PWSetAdvertisingIdRequest Tests

/// Verifies that request uses correct method name.
- (void)testRequest_methodName {
    PWSetAdvertisingIdRequest *request = [[PWSetAdvertisingIdRequest alloc] init];
    XCTAssertEqualObjects([request methodName], @"setMADID");
}

/// Verifies that request uses default tracking base URL.
- (void)testRequest_defaultBaseUrl {
    PWSetAdvertisingIdRequest *request = [[PWSetAdvertisingIdRequest alloc] init];

    XCTAssertEqualObjects([request baseUrl], @"https://tracking.svc-nue.pushwoosh.com/api/v2/device-api/");
}

/// Verifies that request dictionary contains madid field.
- (void)testRequest_requestDictionary_containsAdvertisingId {
    PWSetAdvertisingIdRequest *request = [[PWSetAdvertisingIdRequest alloc] init];
    request.advertisingId = @"test-idfa-456";

    NSDictionary *dict = [request requestDictionary];

    XCTAssertEqualObjects(dict[@"madid"], @"test-idfa-456");
    XCTAssertNotNil(dict[@"hwid"]);
    XCTAssertNotNil(dict[@"application"]);
    XCTAssertNil(dict[@"v"]);
    XCTAssertNil(dict[@"device_type"]);
    XCTAssertNil(dict[@"userId"]);
}

/// Verifies that nil advertisingId sends NSNull in request.
- (void)testRequest_requestDictionary_nilSendsNull {
    PWSetAdvertisingIdRequest *request = [[PWSetAdvertisingIdRequest alloc] init];
    request.advertisingId = nil;

    NSDictionary *dict = [request requestDictionary];

    XCTAssertEqualObjects(dict[@"madid"], [NSNull null]);
}

#pragma mark - PushwooshConfig setAdvertisingId Tests

/// Verifies that setAdvertisingId sends a request when server communication is allowed.
- (void)testSetAdvertisingId_sendsRequest {
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    OCMStub([mockNetworkModule requestManager]).andReturn(mockRequestManager);

    id mockServerComm = OCMClassMock([PWServerCommunicationManager class]);
    OCMStub([mockServerComm sharedInstance]).andReturn(mockServerComm);
    OCMStub([mockServerComm isServerCommunicationAllowed]).andReturn(YES);

    OCMExpect([mockRequestManager sendRequest:[OCMArg checkWithBlock:^BOOL(PWSetAdvertisingIdRequest *request) {
        return [request.advertisingId isEqualToString:@"sent-idfa"];
    }] completion:OCMOCK_ANY]);

    [PushwooshConfig setAdvertisingId:@"sent-idfa"];

    OCMVerifyAll(mockRequestManager);

    [mockServerComm stopMocking];
    [mockNetworkModule stopMocking];
    [mockRequestManager stopMocking];
}

/// Verifies that setAdvertisingId does NOT send when server communication is disabled.
- (void)testSetAdvertisingId_noSendWhenCommDisabled {
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    OCMStub([mockNetworkModule requestManager]).andReturn(mockRequestManager);

    id mockServerComm = OCMClassMock([PWServerCommunicationManager class]);
    OCMStub([mockServerComm sharedInstance]).andReturn(mockServerComm);
    OCMStub([mockServerComm isServerCommunicationAllowed]).andReturn(NO);

    [[mockRequestManager reject] sendRequest:OCMOCK_ANY completion:OCMOCK_ANY];

    [PushwooshConfig setAdvertisingId:@"blocked-idfa"];

    OCMVerifyAll(mockRequestManager);

    [mockServerComm stopMocking];
    [mockNetworkModule stopMocking];
    [mockRequestManager stopMocking];
}

/// Verifies that duplicate value does not send request.
- (void)testSetAdvertisingId_dedup_doesNotSend {
    [[PWPreferences preferences] setAdvertisingId:@"dedup-idfa"];

    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    OCMStub([mockNetworkModule requestManager]).andReturn(mockRequestManager);

    id mockServerComm = OCMClassMock([PWServerCommunicationManager class]);
    OCMStub([mockServerComm sharedInstance]).andReturn(mockServerComm);
    OCMStub([mockServerComm isServerCommunicationAllowed]).andReturn(YES);

    [[mockRequestManager reject] sendRequest:OCMOCK_ANY completion:OCMOCK_ANY];

    [PushwooshConfig setAdvertisingId:@"dedup-idfa"];

    OCMVerifyAll(mockRequestManager);

    [mockServerComm stopMocking];
    [mockNetworkModule stopMocking];
    [mockRequestManager stopMocking];
}

/// Verifies that nil when already nil does not send request.
- (void)testSetAdvertisingId_nilWhenAlreadyNil_doesNotSend {
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    OCMStub([mockNetworkModule requestManager]).andReturn(mockRequestManager);

    id mockServerComm = OCMClassMock([PWServerCommunicationManager class]);
    OCMStub([mockServerComm sharedInstance]).andReturn(mockServerComm);
    OCMStub([mockServerComm isServerCommunicationAllowed]).andReturn(YES);

    [[mockRequestManager reject] sendRequest:OCMOCK_ANY completion:OCMOCK_ANY];

    [PushwooshConfig setAdvertisingId:nil];

    OCMVerifyAll(mockRequestManager);

    [mockServerComm stopMocking];
    [mockNetworkModule stopMocking];
    [mockRequestManager stopMocking];
}

/// Verifies that empty string is treated as nil.
- (void)testSetAdvertisingId_emptyString_treatedAsNil {
    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    OCMStub([mockNetworkModule requestManager]).andReturn(mockRequestManager);

    id mockServerComm = OCMClassMock([PWServerCommunicationManager class]);
    OCMStub([mockServerComm sharedInstance]).andReturn(mockServerComm);
    OCMStub([mockServerComm isServerCommunicationAllowed]).andReturn(YES);

    [[mockRequestManager reject] sendRequest:OCMOCK_ANY completion:OCMOCK_ANY];

    [PushwooshConfig setAdvertisingId:@""];

    OCMVerifyAll(mockRequestManager);

    [mockServerComm stopMocking];
    [mockNetworkModule stopMocking];
    [mockRequestManager stopMocking];
}

/// Verifies that different value sends request.
- (void)testSetAdvertisingId_differentValue_sendsRequest {
    [[PWPreferences preferences] setAdvertisingId:@"old-idfa"];

    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    OCMStub([mockNetworkModule requestManager]).andReturn(mockRequestManager);

    id mockServerComm = OCMClassMock([PWServerCommunicationManager class]);
    OCMStub([mockServerComm sharedInstance]).andReturn(mockServerComm);
    OCMStub([mockServerComm isServerCommunicationAllowed]).andReturn(YES);

    OCMExpect([mockRequestManager sendRequest:[OCMArg checkWithBlock:^BOOL(PWSetAdvertisingIdRequest *request) {
        return [request.advertisingId isEqualToString:@"new-idfa"];
    }] completion:OCMOCK_ANY]);

    [PushwooshConfig setAdvertisingId:@"new-idfa"];

    OCMVerifyAll(mockRequestManager);

    [mockServerComm stopMocking];
    [mockNetworkModule stopMocking];
    [mockRequestManager stopMocking];
}

/// Verifies that nil when prev exists sends request.
- (void)testSetAdvertisingId_nilWhenPrevExists_sendsRequest {
    [[PWPreferences preferences] setAdvertisingId:@"existing-idfa"];

    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    OCMStub([mockNetworkModule requestManager]).andReturn(mockRequestManager);

    id mockServerComm = OCMClassMock([PWServerCommunicationManager class]);
    OCMStub([mockServerComm sharedInstance]).andReturn(mockServerComm);
    OCMStub([mockServerComm isServerCommunicationAllowed]).andReturn(YES);

    OCMExpect([mockRequestManager sendRequest:[OCMArg checkWithBlock:^BOOL(PWSetAdvertisingIdRequest *request) {
        return request.advertisingId == nil;
    }] completion:OCMOCK_ANY]);

    [PushwooshConfig setAdvertisingId:nil];

    OCMVerifyAll(mockRequestManager);

    [mockServerComm stopMocking];
    [mockNetworkModule stopMocking];
    [mockRequestManager stopMocking];
}

/// Verifies that setAdvertisingId defers the network request until SDK becomes ready.
- (void)testSetAdvertisingId_deferredUntilSdkReady {
    [[PWSdkStateProvider sharedInstance] resetForTesting];

    id mockRequestManager = OCMClassMock([PWRequestManager class]);
    id mockNetworkModule = OCMClassMock([PWNetworkModule class]);
    OCMStub([mockNetworkModule module]).andReturn(mockNetworkModule);
    OCMStub([mockNetworkModule requestManager]).andReturn(mockRequestManager);

    id mockServerComm = OCMClassMock([PWServerCommunicationManager class]);
    OCMStub([mockServerComm sharedInstance]).andReturn(mockServerComm);
    OCMStub([mockServerComm isServerCommunicationAllowed]).andReturn(YES);

    __block NSInteger sendCount = 0;
    __block NSString *capturedAdvertisingId = nil;
    OCMStub([mockRequestManager sendRequest:[OCMArg any] completion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        sendCount++;
        __unsafe_unretained PWSetAdvertisingIdRequest *request;
        [invocation getArgument:&request atIndex:2];
        capturedAdvertisingId = [request.advertisingId copy];
    });

    [PushwooshConfig setAdvertisingId:@"deferred-idfa"];

    XCTAssertEqual(sendCount, 0, @"Request must not fire while gate is locked");

    [[PWSdkStateProvider sharedInstance] setReady];

    XCTestExpectation *drained = [self expectationWithDescription:@"main queue drained"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [drained fulfill];
    });
    [self waitForExpectations:@[drained] timeout:2.0];

    XCTAssertEqual(sendCount, 1, @"Request must fire exactly once after gate unlock");
    XCTAssertEqualObjects(capturedAdvertisingId, @"deferred-idfa");

    [mockServerComm stopMocking];
    [mockNetworkModule stopMocking];
    [mockRequestManager stopMocking];
}

#pragma mark - Tracking URL Tests

/// Verifies that custom tracking URL from Info.plist is used.
- (void)testRequest_customTrackingUrlFromConfig {
    id mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([mockConfig config]).andReturn(mockConfig);
    OCMStub([mockConfig trackingUrl]).andReturn(@"https://custom.tracking.com/json/1.3");

    PWSetAdvertisingIdRequest *request = [[PWSetAdvertisingIdRequest alloc] init];
    XCTAssertEqualObjects([request baseUrl], @"https://custom.tracking.com/json/1.3/");

    [mockConfig stopMocking];
}

/// Verifies that default tracking URL is used when no config.
- (void)testRequest_defaultTrackingUrlWhenNoConfig {
    id mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([mockConfig config]).andReturn(mockConfig);
    OCMStub([mockConfig trackingUrl]).andReturn(nil);

    PWSetAdvertisingIdRequest *request = [[PWSetAdvertisingIdRequest alloc] init];
    XCTAssertEqualObjects([request baseUrl], @"https://tracking.svc-nue.pushwoosh.com/api/v2/device-api/");

    [mockConfig stopMocking];
}

@end
