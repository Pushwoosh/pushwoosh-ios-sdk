
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PushwooshModuleRegistry.h"
#import "PushwooshModuleIdentifier.h"
#import "PWVoIPConfigureHandler.h"

@interface RegistryVoIPHandlerLookupTest : XCTestCase
@end

@implementation RegistryVoIPHandlerLookupTest

- (void)setUp {
    [super setUp];
    [PushwooshModuleRegistry _resetForTesting];
}

- (void)tearDown {
    [PushwooshModuleRegistry _resetForTesting];
    [super tearDown];
}

/// Verifies that handlerForIdentifier returns nil when no VoIP handler is registered.
- (void)testHandlerIsNilWithoutRegistration {
    id handler = [PushwooshModuleRegistry handlerForIdentifier:PWModuleIdentifierVoIP];

    XCTAssertNil(handler);
}

/// Verifies that a registered handler is returned and receives `configureVoIP`.
- (void)testHandlerTriggersConfigureVoIP {
    id<PWVoIPConfigureHandler> handler = OCMProtocolMock(@protocol(PWVoIPConfigureHandler));
    [PushwooshModuleRegistry registerHandler:handler forIdentifier:PWModuleIdentifierVoIP];

    id<PWVoIPConfigureHandler> resolved =
        [PushwooshModuleRegistry handlerForIdentifier:PWModuleIdentifierVoIP];

    XCTAssertNotNil(resolved);
    [resolved configureVoIP];

    OCMVerify([handler configureVoIP]);
}

@end
