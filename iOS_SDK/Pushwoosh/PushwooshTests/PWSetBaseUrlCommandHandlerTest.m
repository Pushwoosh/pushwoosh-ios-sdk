#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWSetBaseUrlCommandHandler.h"
#import "PWPreferences.h"
#import "PWNetworkModule.h"
#import "PWRequestManager.h"

@interface PWSetBaseUrlCommandHandlerTest : XCTestCase

@property (nonatomic, strong) PWSetBaseUrlCommandHandler *handler;
@property (nonatomic, copy) NSString *savedBaseUrl;

@end

@implementation PWSetBaseUrlCommandHandlerTest

- (void)setUp {
    [super setUp];
    _handler = [PWSetBaseUrlCommandHandler new];
    _savedBaseUrl = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];
}

- (void)tearDown {
    _handler = nil;
    if (_savedBaseUrl.length > 0) {
        [[PWPreferences preferences] updateBaseUrl:_savedBaseUrl];
    }
    [super tearDown];
}

/// SDK-814: Verifies that a malformed URL in the set_base_url command is rejected and the persisted baseUrl is unchanged.
- (void)testSetBaseUrlCommandRejectsMalformedUrl {
    [[PWPreferences preferences] updateBaseUrl:@"https://prior-handler.example.com/"];
    NSString *prior = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];

    BOOL handled = [_handler handleCommand:@{@"value": @"not a url"}];

    XCTAssertFalse(handled);
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"], prior);
}

/// SDK-814: Verifies that a valid URL in the set_base_url command is accepted and persisted with a trailing slash.
- (void)testSetBaseUrlCommandAcceptsValidUrl {
    BOOL handled = [_handler handleCommand:@{@"value": @"https://new.example.com"}];

    XCTAssertTrue(handled);
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"], @"https://new.example.com/");
}

/// SDK-814: Verifies that a missing 'value' key in the command is rejected.
- (void)testSetBaseUrlCommandRejectsMissingValue {
    BOOL handled = [_handler handleCommand:@{}];

    XCTAssertFalse(handled);
}

/// SDK-882: Verifies the command is refused while a reverse proxy is configured, leaving the persisted endpoint untouched.
- (void)testSetBaseUrlCommandIgnoredWhenReverseProxyConfigured {
    [[PWPreferences preferences] updateBaseUrl:@"https://prior-proxy-gate.example.com/"];
    NSString *prior = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];

    PWRequestManager *savedManager = [PWNetworkModule module].requestManager;
    id mockManager = OCMClassMock([PWRequestManager class]);
    OCMStub([mockManager isUsingReverseProxy]).andReturn(YES);
    [PWNetworkModule module].requestManager = mockManager;

    BOOL handled = [_handler handleCommand:@{@"value": @"https://server-moved.example.com/"}];

    XCTAssertFalse(handled);
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"], prior);

    [PWNetworkModule module].requestManager = savedManager;
    [mockManager stopMocking];
}

@end
