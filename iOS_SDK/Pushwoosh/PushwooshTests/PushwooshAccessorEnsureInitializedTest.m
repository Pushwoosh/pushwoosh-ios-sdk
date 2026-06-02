
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <objc/message.h>
#import "Pushwoosh+Internal.h"
#import "PushwooshFramework.h"
#import <PushwooshCore/PWPreferences.h>
#import <PushwooshCore/PushwooshConfig.h>

@interface PushwooshAccessorEnsureInitializedTest : XCTestCase
@end

@implementation PushwooshAccessorEnsureInitializedTest {
    NSString *_savedAppCode;
}

- (void)setUp {
    [super setUp];
    _savedAppCode = [PWPreferences preferences].appCode;
    [PWPreferences preferences].appCode = nil;
    [Pushwoosh _resetEnsureInitializedForTesting];
}

- (void)tearDown {
    [PWPreferences preferences].appCode = _savedAppCode;
    [Pushwoosh _resetEnsureInitializedForTesting];
    [super tearDown];
}

/// Verifies that invoking an optional-module accessor lazily resolves the app
/// code via PushwooshConfig and persists it through PWPreferences.
- (void)testLiveActivitiesAccessorLazilyPersistsAppCodeFromPushwooshConfig {
    id configMock = OCMClassMock([PushwooshConfig class]);
    OCMStub([configMock getAppCode]).andReturn(@"TEST-LACODE");

    (void)[Pushwoosh LiveActivities];

    XCTAssertEqualObjects([PWPreferences preferences].appCode, @"TEST-LACODE");

    [configMock stopMocking];
}

/// Verifies the contract for every accessor that calls +ensureInitialized.
/// Iterates the six module accessors so a regression on any single one is caught.
- (void)testAllModuleAccessorsLazilyPersistAppCode {
    NSArray<NSString *> *selectorNames = @[
        @"LiveActivities",
        @"InboxKit",
        @"VoIP",
        @"ForegroundPush",
        @"TVoS",
        @"Keychain",
    ];

    for (NSString *selectorName in selectorNames) {
        [PWPreferences preferences].appCode = nil;
        [Pushwoosh _resetEnsureInitializedForTesting];

        id configMock = OCMClassMock([PushwooshConfig class]);
        NSString *expected = [@"TEST-" stringByAppendingString:selectorName];
        OCMStub([configMock getAppCode]).andReturn(expected);

        SEL sel = NSSelectorFromString(selectorName);
        XCTAssertTrue([Pushwoosh respondsToSelector:sel], @"Accessor +%@ missing on Pushwoosh", selectorName);
        ((void (*)(id, SEL))objc_msgSend)([Pushwoosh class], sel);

        XCTAssertEqualObjects([PWPreferences preferences].appCode, expected,
                              @"Accessor +%@ did not call ensureInitialized — app code not persisted.",
                              selectorName);

        [configMock stopMocking];
    }
}

/// Verifies that ensureInitialized does not overwrite an app code that was
/// already set through another path (e.g., manual initializeWithAppCode:).
- (void)testEnsureInitializedDoesNotOverwriteExistingAppCode {
    [PWPreferences preferences].appCode = @"PRE-EXISTING";

    id configMock = OCMClassMock([PushwooshConfig class]);
    OCMStub([configMock getAppCode]).andReturn(@"PRE-EXISTING");

    (void)[Pushwoosh LiveActivities];

    XCTAssertEqualObjects([PWPreferences preferences].appCode, @"PRE-EXISTING");

    [configMock stopMocking];
}

/// Verifies that when PushwooshConfig returns nil and PWConfig has no appId,
/// the accessor still returns a non-nil class without crashing.
- (void)testAccessorReturnsClassWhenAppCodeUnavailable {
    id configMock = OCMClassMock([PushwooshConfig class]);
    OCMStub([configMock getAppCode]).andReturn(nil);

    Class result = [Pushwoosh LiveActivities];

    XCTAssertNotNil(result);

    [configMock stopMocking];
}

@end
