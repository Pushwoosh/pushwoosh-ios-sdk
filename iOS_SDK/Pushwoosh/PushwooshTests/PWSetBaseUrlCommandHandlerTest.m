#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWSetBaseUrlCommandHandler.h"
#import "PWPreferences.h"

@interface PWSetBaseUrlCommandHandlerTest : XCTestCase

@property (nonatomic, strong) PWSetBaseUrlCommandHandler *handler;

@end

@implementation PWSetBaseUrlCommandHandlerTest

- (void)setUp {
    [super setUp];
    _handler = [PWSetBaseUrlCommandHandler new];
}

- (void)tearDown {
    _handler = nil;
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

@end
