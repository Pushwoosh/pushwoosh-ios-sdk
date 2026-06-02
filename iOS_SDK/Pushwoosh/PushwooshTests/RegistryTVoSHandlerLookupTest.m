
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PushwooshModuleRegistry.h"
#import "PushwooshModuleIdentifier.h"
#import "PWTVoSInAppHandler.h"

@interface RegistryTVoSHandlerLookupTest : XCTestCase
@end

@implementation RegistryTVoSHandlerLookupTest

- (void)setUp {
    [super setUp];
    [PushwooshModuleRegistry _resetForTesting];
}

- (void)tearDown {
    [PushwooshModuleRegistry _resetForTesting];
    [super tearDown];
}

/// Verifies that handlerForIdentifier returns nil when no TVoS handler is registered.
- (void)testHandlerIsNilWithoutRegistration {
    id handler = [PushwooshModuleRegistry handlerForIdentifier:PWModuleIdentifierTVoS];

    XCTAssertNil(handler);
}

/// Verifies that a registered handler is returned and receives `handleInAppResource:`.
- (void)testHandlerForwardsResource {
    id<PWTVoSInAppHandler> handler = OCMProtocolMock(@protocol(PWTVoSInAppHandler));
    [PushwooshModuleRegistry registerHandler:handler forIdentifier:PWModuleIdentifierTVoS];

    id<PWTVoSInAppHandler> resolved =
        [PushwooshModuleRegistry handlerForIdentifier:PWModuleIdentifierTVoS];

    XCTAssertNotNil(resolved);
    NSString *resource = @"resource-payload";
    [resolved handleInAppResource:resource];

    OCMVerify([handler handleInAppResource:resource]);
}

@end
