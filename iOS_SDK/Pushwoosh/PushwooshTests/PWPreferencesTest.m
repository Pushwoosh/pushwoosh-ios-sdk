//
//  PWPreferencesTest.m
//  PushwooshTests
//
//  Created by Andrei Kiselev on 25.4.23..
//  Copyright © 2023 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWPreferences.h"
#import "PWConfig.h"

@interface PWPreferences (Test)

@property (nonatomic) NSUserDefaults *defaults;
@property (copy) NSString *userId;

+ (NSString *)readAppId;
+ (void)resetCache;

@end

#pragma mark - Suppress deprecation warnings for legacy setBaseUrl: in tests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface PWPreferencesTest : XCTestCase

@property (nonatomic) PWPreferences *settings;
@property (nonatomic) PWConfig *config;


@end

@implementation PWPreferencesTest

- (void)setUp {
    _settings = [PWPreferences preferences];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

/// Verifies that when appGroupsName is empty, PWPreferences reads PWInAppUserId from standardUserDefaults.
- (void)testAppGroupsNameIsEmpty {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(nil);
    id mockNSUserDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMExpect([mockNSUserDefaults objectForKey:@"PWInAppUserId"]).andReturn(@"someUserID");

    _settings = [[PWPreferences alloc] init];

    OCMVerifyAll(mockNSUserDefaults);
    XCTAssertEqualObjects([_settings userId], @"someUserID");

    [mockNSUserDefaults stopMocking];
    [mockConfig stopMocking];
}

/// Verifies that an existing userId stored in standardUserDefaults is preserved when migrating to an App Group.
- (void)testUserUpdatedSDKAndChangeUserDefaultsToAppGroups {
    NSString *appGroupName = @"someAppGroup";
    NSString *prevSavedUserId = @"prevSavedUserId";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(appGroupName);
    id mockNSUserDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMStub([mockNSUserDefaults objectForKey:@"PWInAppUserId"]).andReturn(prevSavedUserId);

    _settings = [[PWPreferences alloc] init];

    XCTAssertEqualObjects([_settings userId], prevSavedUserId);

    [mockNSUserDefaults stopMocking];
    [mockConfig stopMocking];
}

/// Verifies that when appGroupsName is configured, PWPreferences initializes NSUserDefaults via initWithSuiteName:.
- (void)testUserIdFromSuiteName {
    NSString *appGroupName = @"someAppGroup";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(appGroupName);
    id mockNSUserDefaults = OCMClassMock([NSUserDefaults class]);
    OCMStub([mockNSUserDefaults alloc]).andReturn(mockNSUserDefaults);
    OCMExpect([mockNSUserDefaults initWithSuiteName:appGroupName]).andReturn(mockNSUserDefaults);

    _settings = [[PWPreferences alloc] init];

    OCMVerifyAll(mockNSUserDefaults);

    [mockNSUserDefaults stopMocking];
    [mockConfig stopMocking];
}

/// Verifies that setUserId persists the value to standardUserDefaults under the PWInAppUserId key when no App Group is configured.
- (void)testSetUserIdAppGroupNameNil {
    NSString *kUserId = @"PWInAppUserId";
    NSString *mockUserId = @"mockUserId";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(nil);
    id mockNSUserDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMExpect([mockNSUserDefaults setObject:mockUserId forKey:kUserId]);

    [_settings setUserId:mockUserId];

    OCMVerifyAll(mockNSUserDefaults);

    [mockNSUserDefaults stopMocking];
    [mockConfig stopMocking];
}

#pragma mark - SDK-796 Android parity — appCode sharing via App Groups

/// Verifies that setAppCode writes to the shared App Groups suite when appGroupsName is configured.
- (void)testSetAppCode_writesToAppGroupsSharedSuite {
    NSString *appGroupName = @"group.com.pushwoosh.test.appcode-parity";
    NSString *appCode = @"ABCDE-12345";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(appGroupName);

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:appGroupName];
    [shared removeObjectForKey:@"Pushwoosh_APPID"];

    [_settings setAppCode:appCode];

    XCTAssertEqualObjects([shared objectForKey:@"Pushwoosh_APPID"], appCode);

    [shared removeObjectForKey:@"Pushwoosh_APPID"];
    [mockConfig stopMocking];
}

/// Verifies that setAppCode with empty string removes the value from the shared App Groups suite.
- (void)testSetAppCode_emptyStringRemovesFromSharedSuite {
    NSString *appGroupName = @"group.com.pushwoosh.test.appcode-parity";
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(appGroupName);

    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:appGroupName];
    [shared setObject:@"STALE-VALUE" forKey:@"Pushwoosh_APPID"];

    [_settings setAppCode:@""];

    XCTAssertNil([shared objectForKey:@"Pushwoosh_APPID"]);

    [mockConfig stopMocking];
}

/// Verifies that setAppCode does NOT touch the shared suite when appGroupsName is not configured.
- (void)testSetAppCode_noAppGroups_doesNotWriteSharedSuite {
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig appGroupsName]).andReturn(nil);

    XCTAssertNoThrow([_settings setAppCode:@"NO-GROUPS"]);

    [mockConfig stopMocking];
}

#pragma mark - SDK-814: defaultBaseUrl + setAppCode dot-rejection

/// SDK-814: Verifies that defaultBaseUrl returns nil when appCode is empty and no custom requestUrl is set.
- (void)testDefaultBaseUrlEmptyAppCodeReturnsNil {
    NSString *savedAppCode = [_settings.appCode copy];
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(nil);
    [_settings setAppCode:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_APPID"];

    XCTAssertNil([_settings defaultBaseUrl]);

    [_settings setAppCode:savedAppCode];
    [mockConfig stopMocking];
}

/// SDK-814: Verifies that defaultBaseUrl returns nil for a persisted dotted appCode (defence in depth).
- (void)testDefaultBaseUrlDottedAppCodeReturnsNil {
    NSString *savedAppCode = [_settings.appCode copy];
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(nil);
    [_settings setAppCode:nil];

    id mockPrefsClass = OCMClassMock([PWPreferences class]);
    OCMStub([mockPrefsClass readAppId]).andReturn(@"XXXXX-XXXXX.legacy");

    XCTAssertNil([_settings defaultBaseUrl]);

    [mockPrefsClass stopMocking];
    [_settings setAppCode:savedAppCode];
    [mockConfig stopMocking];
}

/// SDK-814: Verifies that defaultBaseUrl builds the canonical api.pushwoosh.com URL for a valid appCode.
- (void)testDefaultBaseUrlCanonicalAppCodeBuildsApiUrl {
    NSString *savedAppCode = [_settings.appCode copy];
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(nil);
    [_settings setAppCode:@"XXXXX-XXXXX"];

    XCTAssertEqualObjects(@"https://XXXXX-XXXXX.api.pushwoosh.com/json/1.3/", [_settings defaultBaseUrl]);

    [_settings setAppCode:savedAppCode];
    [mockConfig stopMocking];
}

/// SDK-814: Verifies that a custom Pushwoosh_BASEURL takes precedence over the auto-built default.
- (void)testDefaultBaseUrlCustomRequestUrlTakesPrecedence {
    NSString *savedAppCode = [_settings.appCode copy];
    id mockConfig = OCMPartialMock([PWConfig config]);
    OCMStub([mockConfig requestUrl]).andReturn(@"https://custom.example.com/json/1.3/");
    [_settings setAppCode:@"XXXXX-XXXXX"];

    XCTAssertEqualObjects(@"https://custom.example.com/json/1.3/", [_settings defaultBaseUrl]);

    [_settings setAppCode:savedAppCode];
    [mockConfig stopMocking];
}

/// SDK-814: Verifies that setAppCode at the preferences chokepoint rejects dotted codes (no overwrite).
- (void)testSetAppCodeDottedIsRejectedAtPreferences {
    NSString *savedAppCode = [_settings.appCode copy];

    [_settings setAppCode:@"CANON-IICAL"];
    NSString *priorAppCode = [_settings.appCode copy];
    NSString *priorPersisted = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_APPID"] copy];

    [_settings setAppCode:@"XXXXX-XXXXX.legacy"];

    XCTAssertEqualObjects(priorAppCode, [_settings appCode]);
    XCTAssertEqualObjects(priorPersisted, [[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_APPID"]);

    [_settings setAppCode:savedAppCode];
}

#pragma mark - SDK-814: baseUrl-pollution rewrite

/// SDK-814: Verifies that readBaseUrl directly discards a persisted cp.pushwoosh.com value
/// without relying on setAppCode's rederive overwriting it. This exercises the iOS-specific
/// load-bearing scrub branch in -readBaseUrl (PWPreferences.m hostname-equality discard).
- (void)testReadBaseUrlDiscardsPersistedCpPushwooshCom {
    NSString *savedAppCode = [_settings.appCode copy];
    NSString *priorPersistedBaseUrl = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];

    // Force appCode to empty so any incidental setAppCode rederive returns early
    // (rederive guard requires appCodeSnapshot.length > 0). This isolates -readBaseUrl
    // as the only writer to KeyBaseUrl during the test body.
    [_settings setAppCode:nil];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_APPID"];

    // Seed legacy URL AFTER setAppCode so it survives into -baseUrl's lazy getter.
    [[NSUserDefaults standardUserDefaults] setObject:@"https://cp.pushwoosh.com/json/1.3/" forKey:@"Pushwoosh_BASEURL"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // Force the cached ivar to nil so the next -baseUrl call invokes -readBaseUrl.
    [_settings setValue:nil forKey:@"baseUrl"];

    NSString *result = [_settings baseUrl];

    // Empty appCode + no requestUrl → -defaultBaseUrl returns nil → -baseUrl returns nil
    // BUT the discard side-effect (removeObjectForKey:KeyBaseUrl) must still have run.
    XCTAssertNil(result, @"baseUrl should be nil when no appCode is configured");
    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"],
                 @"readBaseUrl must clear the persisted legacy cp.pushwoosh.com value");

    // Restore
    if (priorPersistedBaseUrl) {
        [[NSUserDefaults standardUserDefaults] setObject:priorPersistedBaseUrl forKey:@"Pushwoosh_BASEURL"];
    }
    [_settings setAppCode:savedAppCode];
}

/// SDK-814: Verifies that updateBaseUrl appends a missing trailing slash.
- (void)testUpdateBaseUrlNormalizesTrailingSlash {
    NSString *priorPersisted = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];

    NSString *result = [_settings updateBaseUrl:@"https://test-update.example.com"];

    XCTAssertEqualObjects(result, @"https://test-update.example.com/");
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"], @"https://test-update.example.com/");

    if (priorPersisted) {
        [[NSUserDefaults standardUserDefaults] setObject:priorPersisted forKey:@"Pushwoosh_BASEURL"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_BASEURL"];
    }
}

/// SDK-814: Verifies that updateBaseUrl rejects empty and nil input.
- (void)testUpdateBaseUrlRejectsEmpty {
    [_settings updateBaseUrl:@"https://prior.example.com"];
    NSString *prior = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];

    XCTAssertNil([_settings updateBaseUrl:@""]);
    XCTAssertNil([_settings updateBaseUrl:nil]);

    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"], prior);
}

/// SDK-814: Verifies that updateBaseUrl rejects URLs containing internal whitespace.
- (void)testUpdateBaseUrlRejectsWhitespaceInside {
    [_settings updateBaseUrl:@"https://prior2.example.com"];
    NSString *prior = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];

    XCTAssertNil([_settings updateBaseUrl:@"https://foo bar.com/"]);

    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"], prior);
}

/// SDK-814: Verifies that updateBaseUrl rejects non-http(s) schemes.
- (void)testUpdateBaseUrlRejectsBadScheme {
    [_settings updateBaseUrl:@"https://prior3.example.com"];
    NSString *prior = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];

    XCTAssertNil([_settings updateBaseUrl:@"ftp://example.com/"]);

    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"], prior);
}

/// SDK-814: Verifies that updateBaseUrl rejects malformed URLs without a host.
- (void)testUpdateBaseUrlRejectsMalformed {
    [_settings updateBaseUrl:@"https://prior4.example.com"];
    NSString *prior = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];

    XCTAssertNil([_settings updateBaseUrl:@"https://"]);

    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"], prior);
}

/// SDK-814: Verifies that updateBaseUrl returns the normalized value without rewriting NSUserDefaults when the value is unchanged.
- (void)testUpdateBaseUrlDeDuplicates {
    NSString *url = @"https://dedup.example.com/";
    [_settings updateBaseUrl:url];

    id mockDefaults = OCMPartialMock([NSUserDefaults standardUserDefaults]);
    OCMReject([mockDefaults setObject:url forKey:@"Pushwoosh_BASEURL"]);

    NSString *result = [_settings updateBaseUrl:url];
    XCTAssertEqualObjects(result, url);

    OCMVerifyAll(mockDefaults);
    [mockDefaults stopMocking];
}

/// SDK-814: Verifies that setAppCode rederives the default baseUrl when KeyBaseUrl is empty.
- (void)testSetAppCodeRederivesDefaultWhenBaseUrlEmpty {
    NSString *savedAppCode = [_settings.appCode copy];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_BASEURL"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    [_settings setAppCode:@"BBBBB-22222"];

    XCTAssertEqualObjects([_settings baseUrl], @"https://BBBBB-22222.api.pushwoosh.com/json/1.3/");

    [_settings setAppCode:savedAppCode];
}

/// SDK-814: Verifies that setAppCode does not clobber a customer-set baseUrl when persisted.
- (void)testSetAppCodeDoesNotClobberCustomBaseUrl {
    NSString *savedAppCode = [_settings.appCode copy];

    [_settings setAppCode:@"CCCCC-33333"];
    [_settings updateBaseUrl:@"https://custom.example.com/json/1.3/"];

    [_settings setAppCode:@"CCCCC-33333"];

    XCTAssertEqualObjects([_settings baseUrl], @"https://custom.example.com/json/1.3/");

    [_settings setAppCode:savedAppCode];
}

/// SDK-814: Verifies that the deprecated setBaseUrl funnels through updateBaseUrl and normalizes the value.
- (void)testSetBaseUrlDeprecatedFunnelsThroughUpdate {
    [_settings setBaseUrl:@"https://legacy-setter.example.com"];

    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"], @"https://legacy-setter.example.com/");
}

/// SDK-814: End-to-end warm-boot — when an upgrader has BOTH persisted appCode AND legacy
/// cp.pushwoosh.com URL, fresh PWPreferences init resolves baseUrl to the canonical default.
/// The legacy URL is discarded by -readBaseUrl on first lazy access (the persisted entry
/// is removed). Canonical re-persistence happens on the next cold-boot when -setAppCode:
/// observes an empty KeyBaseUrl and rederives. Two-phase wash is intentional and mirrors
/// Android RegistrationPrefs.setAppId semantics (rederive only when persistence is empty).
- (void)testWarmBootRederivesCanonicalUrlOverPersistedLegacy {
    NSString *savedAppId = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_APPID"] copy];
    NSString *savedBaseUrl = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];
    NSString *savedInfoPlistAppId = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_INFO_PLIST_APPID"] copy];

    [[NSUserDefaults standardUserDefaults] setObject:@"WBOOT-99999" forKey:@"Pushwoosh_APPID"];
    [[NSUserDefaults standardUserDefaults] setObject:@"https://cp.pushwoosh.com/json/1.3/" forKey:@"Pushwoosh_BASEURL"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_INFO_PLIST_APPID"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    PWPreferences *fresh = [[PWPreferences alloc] init];

    XCTAssertEqualObjects([fresh baseUrl], @"https://WBOOT-99999.api.pushwoosh.com/json/1.3/",
                          @"baseUrl getter must resolve to canonical even when persisted legacy cp.pushwoosh.com exists");
    XCTAssertNil([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"],
                 @"readBaseUrl must clear the persisted legacy cp.pushwoosh.com value");

    PWPreferences *secondBoot = [[PWPreferences alloc] init];
    XCTAssertEqualObjects([secondBoot baseUrl], @"https://WBOOT-99999.api.pushwoosh.com/json/1.3/");
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"],
                          @"https://WBOOT-99999.api.pushwoosh.com/json/1.3/",
                          @"Second cold-boot must persist the canonical URL via setAppCode rederive");

    if (savedAppId) {
        [[NSUserDefaults standardUserDefaults] setObject:savedAppId forKey:@"Pushwoosh_APPID"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_APPID"];
    }
    if (savedBaseUrl) {
        [[NSUserDefaults standardUserDefaults] setObject:savedBaseUrl forKey:@"Pushwoosh_BASEURL"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_BASEURL"];
    }
    if (savedInfoPlistAppId) {
        [[NSUserDefaults standardUserDefaults] setObject:savedInfoPlistAppId forKey:@"Pushwoosh_INFO_PLIST_APPID"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

/// SDK-814 fixup: On cold-boot, a backend-assigned sharded baseUrl persisted in
/// NSUserDefaults must survive PWPreferences re-init. setAppCode's rederive must only
/// fire when persistence is empty — never overwrite a non-empty persisted URL with the
/// canonical default. Mirrors Android RegistrationPrefs.setAppId: re-derive only when
/// TextUtils.isEmpty(currentBaseUrl).
- (void)testColdBootPreservesPersistedShardUrl {
    NSString *savedAppId = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_APPID"] copy];
    NSString *savedBaseUrl = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"] copy];
    NSString *savedInfoPlistAppId = [[[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_INFO_PLIST_APPID"] copy];

    [[NSUserDefaults standardUserDefaults] setObject:@"SHARD-12345" forKey:@"Pushwoosh_APPID"];
    [[NSUserDefaults standardUserDefaults] setObject:@"https://shard-eu.example.com/json/1.3/" forKey:@"Pushwoosh_BASEURL"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_INFO_PLIST_APPID"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    PWPreferences *fresh = [[PWPreferences alloc] init];

    XCTAssertEqualObjects([fresh baseUrl], @"https://shard-eu.example.com/json/1.3/",
                          @"Persisted sharded baseUrl must survive cold-boot init");
    XCTAssertEqualObjects([[NSUserDefaults standardUserDefaults] objectForKey:@"Pushwoosh_BASEURL"],
                          @"https://shard-eu.example.com/json/1.3/",
                          @"setAppCode rederive must not clobber a non-empty persisted URL");

    if (savedAppId) {
        [[NSUserDefaults standardUserDefaults] setObject:savedAppId forKey:@"Pushwoosh_APPID"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_APPID"];
    }
    if (savedBaseUrl) {
        [[NSUserDefaults standardUserDefaults] setObject:savedBaseUrl forKey:@"Pushwoosh_BASEURL"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"Pushwoosh_BASEURL"];
    }
    if (savedInfoPlistAppId) {
        [[NSUserDefaults standardUserDefaults] setObject:savedInfoPlistAppId forKey:@"Pushwoosh_INFO_PLIST_APPID"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - SDK-816: lastKnockTriggerTimestamp persistence

/// SDK-816: Verifies that lastKnockTriggerTimestamp is persisted across PWPreferences instances.
- (void)testLastKnockTriggerTimestampRoundTrip {
    NSTimeInterval saved = [_settings lastKnockTriggerTimestamp];

    NSTimeInterval value = 1234567.89;
    [_settings setLastKnockTriggerTimestamp:value];

    PWPreferences *fresh = [[PWPreferences alloc] init];

    XCTAssertEqualWithAccuracy([fresh lastKnockTriggerTimestamp], value, 0.001);

    [_settings setLastKnockTriggerTimestamp:saved];
}

/// SDK-816: Verifies that +resetCache wipes the knock cooldown timestamp (ADR-3 contract).
- (void)testResetCacheClearsLastKnockTriggerTimestamp {
    [_settings setLastKnockTriggerTimestamp:1234567.89];
    XCTAssertEqualWithAccuracy([_settings lastKnockTriggerTimestamp], 1234567.89, 0.001);

    [PWPreferences resetCache];

    PWPreferences *fresh = [[PWPreferences alloc] init];
    XCTAssertEqualWithAccuracy([fresh lastKnockTriggerTimestamp], 0.0, 0.001);
}

@end

#pragma clang diagnostic pop
