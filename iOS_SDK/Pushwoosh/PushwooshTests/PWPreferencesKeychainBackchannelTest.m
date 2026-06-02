
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWPreferences.h"
#import "PushwooshModuleRegistry.h"
#import "PushwooshModuleIdentifier.h"
#import "PWKeychainPersistentHWIDProvider.h"

@interface PWPreferences (PWPreferencesKeychainBackchannelTest)
- (NSString *)getPersistentHWIDIfAvailable;
@end

@interface PWPreferencesKeychainBackchannelTest : XCTestCase
@end

@implementation PWPreferencesKeychainBackchannelTest

- (void)setUp {
    [super setUp];
    [PushwooshModuleRegistry _resetForTesting];
}

- (void)tearDown {
    [PushwooshModuleRegistry _resetForTesting];
    [super tearDown];
}

/// Verifies that getPersistentHWIDIfAvailable returns nil when no Keychain handler is registered.
- (void)testReturnsNilWithoutHandler {
    NSString *result = [[PWPreferences preferences] getPersistentHWIDIfAvailable];

    XCTAssertNil(result);
}

/// Verifies that a registered handler is consulted and its value forwarded.
- (void)testForwardsToHandlerWhenRegistered {
    id<PWKeychainPersistentHWIDProvider> handler = OCMProtocolMock(@protocol(PWKeychainPersistentHWIDProvider));
    OCMStub([handler isPersistentHWIDEnabled]).andReturn(YES);
    OCMStub([handler persistentHWID]).andReturn(@"persisted-hwid-1234");
    [PushwooshModuleRegistry registerHandler:handler forIdentifier:PWModuleIdentifierKeychain];

    NSString *result = [[PWPreferences preferences] getPersistentHWIDIfAvailable];

    XCTAssertEqualObjects(result, @"persisted-hwid-1234");
    OCMVerify([handler isPersistentHWIDEnabled]);
    OCMVerify([handler persistentHWID]);
}

/// Verifies that a disabled handler short-circuits and persistentHWID is never called.
- (void)testReturnsNilWhenHandlerDisabled {
    id<PWKeychainPersistentHWIDProvider> handler = OCMProtocolMock(@protocol(PWKeychainPersistentHWIDProvider));
    OCMStub([handler isPersistentHWIDEnabled]).andReturn(NO);
    OCMReject([handler persistentHWID]);
    [PushwooshModuleRegistry registerHandler:handler forIdentifier:PWModuleIdentifierKeychain];

    NSString *result = [[PWPreferences preferences] getPersistentHWIDIfAvailable];

    XCTAssertNil(result);
    OCMVerifyAll((id)handler);
}

@end
