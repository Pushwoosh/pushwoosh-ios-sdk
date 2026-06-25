#import <XCTest/XCTest.h>
#import <PushwooshCore/PWIntegrationValidator.h>

@interface PWIntegrationValidator (Test)

+ (NSArray<PWIntegrationFinding *> *)runChecksWithBundle:(NSBundle *)bundle;
+ (NSArray<PWIntegrationFinding *> *)runChecksWithBundle:(NSBundle *)bundle
                                         resolvedAppCode:(NSString *)resolvedAppCode
                                        resolvedApiToken:(NSString *)resolvedApiToken;

@end

@interface PWValidatorBundleMock : NSBundle

@property (nonatomic, copy) NSDictionary *stubInfo;

@end

@implementation PWValidatorBundleMock

- (NSDictionary *)infoDictionary {
    return self.stubInfo;
}

- (id)objectForInfoDictionaryKey:(NSString *)key {
    return self.stubInfo[key];
}

- (NSURL *)builtInPlugInsURL {
    return nil;
}

@end

@interface PWIntegrationValidatorTest : XCTestCase

@end

@implementation PWIntegrationValidatorTest

- (PWValidatorBundleMock *)bundleWithInfo:(NSDictionary *)info {
    PWValidatorBundleMock *bundle = [PWValidatorBundleMock new];
    bundle.stubInfo = info;
    return bundle;
}

- (PWIntegrationFinding *)findingWithRule:(NSString *)ruleId in:(NSArray<PWIntegrationFinding *> *)findings {
    for (PWIntegrationFinding *finding in findings) {
        if ([finding.ruleId isEqualToString:ruleId]) {
            return finding;
        }
    }
    return nil;
}

/// Verifies that a correctly configured bundle produces no error-level findings.
- (void)testValidConfigurationProducesNoErrors {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"Pushwoosh_API_TOKEN": @"token"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    for (PWIntegrationFinding *finding in findings) {
        XCTAssertNotEqual(finding.severity, PWIntegrationSeverityError, @"Unexpected error: %@", finding.message);
    }
    XCTAssertEqual([self findingWithRule:@"appid.present" in:findings].severity, PWIntegrationSeverityOK);
    XCTAssertEqual([self findingWithRule:@"apitoken.present" in:findings].severity, PWIntegrationSeverityOK);
}

/// Verifies that a missing Pushwoosh_APPID produces an error finding.
- (void)testMissingAppIdProducesError {
    NSBundle *bundle = [self bundleWithInfo:@{}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    PWIntegrationFinding *finding = [self findingWithRule:@"appid.present" in:findings];
    XCTAssertEqual(finding.severity, PWIntegrationSeverityError);
    XCTAssertNotNil(finding.fixHint);
}

/// Verifies that a dotted application id with no runtime fallback is reported as an error.
- (void)testDottedAppIdWithoutRuntimeCodeProducesError {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"00000.11111"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertEqual([self findingWithRule:@"appid.deprecated" in:findings].severity, PWIntegrationSeverityError);
}

/// Verifies that a dotted application id is downgraded to a warning when the SDK resolved a working code.
- (void)testDottedAppIdWithRuntimeCodeProducesWarning {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"00000.11111"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle
                                                                            resolvedAppCode:@"12345-67890"
                                                                           resolvedApiToken:nil];

    XCTAssertEqual([self findingWithRule:@"appid.deprecated" in:findings].severity, PWIntegrationSeverityWarning);
}

/// Verifies that a dotted Pushwoosh_APPID_Dev is reported as deprecated.
- (void)testDottedAppIdDevProducesWarning {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"Pushwoosh_APPID_Dev": @"00000.11111"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    PWIntegrationFinding *finding = [self findingWithRule:@"appid.deprecated" in:findings];
    XCTAssertEqual(finding.severity, PWIntegrationSeverityWarning);
    XCTAssertTrue([finding.message containsString:@"Pushwoosh_APPID_Dev"]);
}

/// Verifies that an app id not matching XXXXX-XXXXX is reported as a format warning.
- (void)testMalformedAppIdProducesFormatWarning {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"notanappcode"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertEqual([self findingWithRule:@"appid.format" in:findings].severity, PWIntegrationSeverityWarning);
}

/// Verifies that a missing API token is reported as a warning.
- (void)testMissingApiTokenProducesWarning {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertEqual([self findingWithRule:@"apitoken.present" in:findings].severity, PWIntegrationSeverityWarning);
}

/// Verifies that the legacy PW_API_TOKEN key satisfies the API token check.
- (void)testLegacyApiTokenIsAccepted {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"PW_API_TOKEN": @"legacy-token"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    PWIntegrationFinding *finding = [self findingWithRule:@"apitoken.present" in:findings];
    XCTAssertEqual(finding.severity, PWIntegrationSeverityOK);
    XCTAssertTrue([finding.message containsString:@"PW_API_TOKEN"]);
}

/// Verifies that a misspelled configuration key is detected and the correct key is suggested.
- (void)testTypoKeyProducesSuggestion {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"Pushwoosh_API_TOCKEN": @"token"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    PWIntegrationFinding *finding = [self findingWithRule:@"plist.typo" in:findings];
    XCTAssertEqual(finding.severity, PWIntegrationSeverityWarning);
    XCTAssertTrue([finding.message containsString:@"Pushwoosh_API_TOKEN"]);
}

/// Verifies that a known key with wrong casing is reported as a typo with the correct spelling suggested.
- (void)testWrongCaseKeyProducesSuggestion {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"pushwoosh_api_token": @"token"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    PWIntegrationFinding *finding = [self findingWithRule:@"plist.typo" in:findings];
    XCTAssertEqual(finding.severity, PWIntegrationSeverityWarning);
    XCTAssertTrue([finding.message containsString:@"Pushwoosh_API_TOKEN"]);
}

/// Verifies that an unrecognized Pushwoosh-prefixed key produces an informational finding.
- (void)testUnknownPushwooshKeyProducesInfo {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"Pushwoosh_TOTALLY_UNKNOWN_FLAG": @YES}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    PWIntegrationFinding *finding = [self findingWithRule:@"plist.unknown" in:findings];
    XCTAssertEqual(finding.severity, PWIntegrationSeverityInfo);
    XCTAssertTrue([finding.message containsString:@"Pushwoosh_TOTALLY_UNKNOWN_FLAG"]);
}

/// Verifies that supported legacy and auxiliary keys are not flagged by the typo scan.
- (void)testSupportedLegacyKeysAreNotFlagged {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"PW_API_TOKEN": @"legacy-token",
                                              @"Pushwoosh_DEBUG": @YES,
                                              @"PWAutoAcceptDeepLinkForSilentPush": @YES}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertNil([self findingWithRule:@"plist.typo" in:findings]);
    XCTAssertNil([self findingWithRule:@"plist.unknown" in:findings]);
}

/// Verifies that non-Pushwoosh Info.plist keys are ignored by the typo scan.
- (void)testForeignKeysAreIgnored {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"CFBundleShortVersionString": @"1.0",
                                              @"UILaunchStoryboardName": @"LaunchScreen"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertNil([self findingWithRule:@"plist.typo" in:findings]);
    XCTAssertNil([self findingWithRule:@"plist.unknown" in:findings]);
}

/// Verifies that a foreign key lexically close to a Pushwoosh key is not flagged as a typo.
- (void)testForeignKeyNearPushwooshKeyIsNotFlagged {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"MY_API_TOKEN": @"customer-token"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertNil([self findingWithRule:@"plist.typo" in:findings]);
    XCTAssertNil([self findingWithRule:@"plist.unknown" in:findings]);
}

/// Verifies that a missing remote-notification background mode produces an informational finding.
- (void)testMissingRemoteNotificationBackgroundModeProducesInfo {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertEqual([self findingWithRule:@"backgroundmodes.remote" in:findings].severity, PWIntegrationSeverityInfo);
}

/// Verifies that an enabled remote-notification background mode is reported as OK.
- (void)testRemoteNotificationBackgroundModeProducesOK {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"UIBackgroundModes": @[@"remote-notification"]}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertEqual([self findingWithRule:@"backgroundmodes.remote" in:findings].severity, PWIntegrationSeverityOK);
}

/// Verifies that a missing Notification Service Extension produces an informational finding.
- (void)testMissingNSEProducesInfo {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertEqual([self findingWithRule:@"nse.present" in:findings].severity, PWIntegrationSeverityInfo);
}

/// Verifies that the app group rule is skipped entirely when PW_APP_GROUPS_NAME is not set.
- (void)testNoAppGroupKeyProducesNoAppGroupFinding {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertNil([self findingWithRule:@"appgroup.reachable" in:findings]);
}

/// Verifies that the gRPC rule warns when Pushwoosh_PREFER_GRPC is set without the module linked.
- (void)testPreferGRPCWithoutModuleProducesWarning {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"Pushwoosh_PREFER_GRPC": @YES}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    PWIntegrationFinding *finding = [self findingWithRule:@"module.grpc" in:findings];
    XCTAssertNotNil(finding);
    XCTAssertEqual(finding.severity, PWIntegrationSeverityWarning);
}

/// Verifies that an app code provided at runtime satisfies the appid rule when Info.plist has no key.
- (void)testRuntimeAppCodeSatisfiesAppIdCheck {
    NSBundle *bundle = [self bundleWithInfo:@{}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle
                                                                            resolvedAppCode:@"12345-67890"
                                                                           resolvedApiToken:nil];

    PWIntegrationFinding *finding = [self findingWithRule:@"appid.present" in:findings];
    XCTAssertEqual(finding.severity, PWIntegrationSeverityOK);
    XCTAssertTrue([finding.message containsString:@"set at runtime"]);
}

/// Verifies that a runtime app code is still validated against the expected XXXXX-XXXXX format.
- (void)testRuntimeAppCodeStillValidatesFormat {
    NSBundle *bundle = [self bundleWithInfo:@{}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle
                                                                            resolvedAppCode:@"notanappcode"
                                                                           resolvedApiToken:nil];

    XCTAssertEqual([self findingWithRule:@"appid.format" in:findings].severity, PWIntegrationSeverityWarning);
}

/// Verifies that an API token provided at runtime satisfies the token rule when Info.plist has no token keys.
- (void)testRuntimeApiTokenSatisfiesTokenCheck {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle
                                                                            resolvedAppCode:nil
                                                                           resolvedApiToken:@"runtime-token"];

    PWIntegrationFinding *finding = [self findingWithRule:@"apitoken.present" in:findings];
    XCTAssertEqual(finding.severity, PWIntegrationSeverityOK);
    XCTAssertTrue([finding.message containsString:@"set at runtime"]);
}

/// Verifies that a present PW_APP_GROUPS_NAME yields no app-group finding on the simulator — the
/// reachability check is device-only, so a present key must not be conflated with the no-key path.
- (void)testAppGroupKeyPresentIsSkippedOnSimulator {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890",
                                              @"PW_APP_GROUPS_NAME": @"group.com.example.app"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertNil([self findingWithRule:@"appgroup.reachable" in:findings]);
}

/// Verifies that the gRPC rule stays silent when Pushwoosh_PREFER_GRPC is not set.
- (void)testNoPreferGRPCProducesNoModuleFinding {
    NSBundle *bundle = [self bundleWithInfo:@{@"Pushwoosh_APPID": @"12345-67890"}];
    NSArray<PWIntegrationFinding *> *findings = [PWIntegrationValidator runChecksWithBundle:bundle];

    XCTAssertNil([self findingWithRule:@"module.grpc" in:findings]);
}

@end
