
#import <XCTest/XCTest.h>
#import "PushwooshModuleRegistry.h"
#import "PushwooshModuleIdentifier.h"
#import "PWMissingModule.h"

@interface PushwooshModuleRegistryTest : XCTestCase
@end

@implementation PushwooshModuleRegistryTest

- (void)setUp {
    [super setUp];
    [PushwooshModuleRegistry _resetForTesting];
}

- (void)tearDown {
    [PushwooshModuleRegistry _resetForTesting];
    [super tearDown];
}

/// Verifies that a registered class is returned by classForIdentifier:.
- (void)testRegisterAndLookupClass {
    [PushwooshModuleRegistry registerClass:[NSString class] forIdentifier:PWModuleIdentifierVoIP];

    XCTAssertEqualObjects([PushwooshModuleRegistry classForIdentifier:PWModuleIdentifierVoIP], [NSString class]);
}

/// Verifies that lookup of an unregistered identifier returns PWMissingModule.
- (void)testUnknownIdentifierReturnsMissingModule {
    Class result = [PushwooshModuleRegistry classForIdentifier:PWModuleIdentifierLiveActivities];

    XCTAssertEqualObjects(result, [PWMissingModule class]);
}

/// Verifies that a registered handler instance is returned by handlerForIdentifier:.
- (void)testRegisterAndLookupHandler {
    NSObject *handler = [NSObject new];
    [PushwooshModuleRegistry registerHandler:handler forIdentifier:PWModuleIdentifierKeychain];

    XCTAssertEqual([PushwooshModuleRegistry handlerForIdentifier:PWModuleIdentifierKeychain], handler);
}

/// Verifies that lookup of an unregistered handler identifier returns nil.
- (void)testUnknownHandlerIdentifierReturnsNil {
    XCTAssertNil([PushwooshModuleRegistry handlerForIdentifier:PWModuleIdentifierVoIP]);
}

/// Verifies that registering a second class for the same identifier overwrites the first.
- (void)testRegisterClassOverwrites {
    [PushwooshModuleRegistry registerClass:[NSString class] forIdentifier:PWModuleIdentifierVoIP];
    [PushwooshModuleRegistry registerClass:[NSArray class] forIdentifier:PWModuleIdentifierVoIP];

    XCTAssertEqualObjects([PushwooshModuleRegistry classForIdentifier:PWModuleIdentifierVoIP], [NSArray class]);
}

/// Verifies that nil class is rejected silently and lookup falls back to PWMissingModule.
- (void)testRegisterNilClassIgnored {
    [PushwooshModuleRegistry registerClass:Nil forIdentifier:PWModuleIdentifierVoIP];

    XCTAssertEqualObjects([PushwooshModuleRegistry classForIdentifier:PWModuleIdentifierVoIP], [PWMissingModule class]);
}

/// Verifies that registrations are independent across identifiers.
- (void)testRegistrationsAreIndependent {
    [PushwooshModuleRegistry registerClass:[NSString class] forIdentifier:PWModuleIdentifierVoIP];
    [PushwooshModuleRegistry registerClass:[NSArray class] forIdentifier:PWModuleIdentifierKeychain];

    XCTAssertEqualObjects([PushwooshModuleRegistry classForIdentifier:PWModuleIdentifierVoIP], [NSString class]);
    XCTAssertEqualObjects([PushwooshModuleRegistry classForIdentifier:PWModuleIdentifierKeychain], [NSArray class]);
}

/// Verifies that _resetForTesting clears every registration.
- (void)testResetForTestingClearsState {
    [PushwooshModuleRegistry registerClass:[NSString class] forIdentifier:PWModuleIdentifierVoIP];
    NSObject *handler = [NSObject new];
    [PushwooshModuleRegistry registerHandler:handler forIdentifier:PWModuleIdentifierKeychain];

    [PushwooshModuleRegistry _resetForTesting];

    XCTAssertEqualObjects([PushwooshModuleRegistry classForIdentifier:PWModuleIdentifierVoIP], [PWMissingModule class]);
    XCTAssertNil([PushwooshModuleRegistry handlerForIdentifier:PWModuleIdentifierKeychain]);
}

/// Verifies that concurrent reads and barrier writes do not crash under heavy load and that
/// committed writes are visible to subsequent reads.
- (void)testConcurrentReadsBarrierWrites {
    NSArray<PushwooshModuleIdentifier> *identifiers = @[
        PWModuleIdentifierLiveActivities,
        PWModuleIdentifierInboxKit,
        PWModuleIdentifierVoIP,
        PWModuleIdentifierForegroundPush,
        PWModuleIdentifierTVoS,
        PWModuleIdentifierKeychain,
    ];

    dispatch_apply(10000, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t i) {
        PushwooshModuleIdentifier identifier = identifiers[i % identifiers.count];
        if (i % 4 == 0) {
            [PushwooshModuleRegistry registerClass:[NSString class] forIdentifier:identifier];
        } else {
            Class cls = [PushwooshModuleRegistry classForIdentifier:identifier];
            XCTAssertNotNil(cls);
        }
    });

    [PushwooshModuleRegistry _resetForTesting];

    for (PushwooshModuleIdentifier identifier in identifiers) {
        [PushwooshModuleRegistry registerClass:[NSObject class] forIdentifier:identifier];
        XCTAssertEqualObjects([PushwooshModuleRegistry classForIdentifier:identifier], [NSObject class],
                              @"Round-trip read did not see committed write for identifier %@", identifier);
    }

    NSObject *handler = [NSObject new];
    [PushwooshModuleRegistry registerHandler:handler forIdentifier:PWModuleIdentifierKeychain];
    XCTAssertEqual([PushwooshModuleRegistry handlerForIdentifier:PWModuleIdentifierKeychain], handler);
}

@end
