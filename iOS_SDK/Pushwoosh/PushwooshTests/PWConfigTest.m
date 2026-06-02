#import <XCTest/XCTest.h>
#import "PWConfig.h"
#import "PWBundleMock.h"

@interface PWConfigTest : XCTestCase

@property (nonatomic) PWConfig *config;

@end

@implementation PWConfigTest

/// Verifies that sendPushStatIfAlertsDisabled reads back NO from the Pushwoosh_SHOULD_SEND_PUSH_STATS_IF_ALERT_DISABLED Info.plist key.
- (void)testSendPushStatIfAlertsDisabledNo {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.sendPushStatIfAlertsDisabled = NO;

    _config = [[PWConfig alloc] initWithBundle:bundleMock];

    XCTAssertFalse(_config.sendPushStatIfAlertsDisabled);
}

/// Verifies that sendPushStatIfAlertsDisabled reads back YES from the Pushwoosh_SHOULD_SEND_PUSH_STATS_IF_ALERT_DISABLED Info.plist key.
- (void)testSendPushStatIfAlertsDisabledYes {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.sendPushStatIfAlertsDisabled = YES;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];

    XCTAssertTrue(_config.sendPushStatIfAlertsDisabled);
}

/// Verifies that sendPurchaseTrackingEnabled reads back YES from the Pushwoosh_PURCHASE_TRACKING_ENABLED Info.plist key.
- (void)testSendPurchaseTrackingEnabled {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.sendPurchaseTrackingEnabled = YES;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];

    XCTAssertTrue(_config.sendPurchaseTrackingEnabled);
}

/// Verifies that idle tracking is disabled when no timeout key is configured (Android parity).
- (void)testIdleTimeoutKeyAbsentDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that idle timeout uses configured value when above minimum.
- (void)testIdleTimeoutUsesConfiguredValue {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @60;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(60, _config.idleTimeoutSeconds);
}

/// Verifies that idle timeout below 30s is clamped to the 30s minimum.
- (void)testIdleTimeoutBelowMinimumIsClamped {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @10;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.idleTimeoutSeconds);
}

/// Verifies that explicit zero disables idle tracking entirely (Android parity).
- (void)testIdleTimeoutZeroDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @0;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that negative values disable idle tracking (Android parity).
- (void)testIdleTimeoutNegativeDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @(-5);
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that value of 1 is clamped to the 30s minimum with a warning.
- (void)testIdleTimeoutOneIsClamped {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @1;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.idleTimeoutSeconds);
}

/// Verifies that value of 5 is clamped to the 30s minimum (below-minimum path).
- (void)testIdleTimeoutFiveIsClamped {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @5;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.idleTimeoutSeconds);
}

/// Verifies that value of 29 (just below boundary) is clamped to the 30s minimum.
- (void)testIdleTimeoutTwentyNineIsClamped {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @29;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.idleTimeoutSeconds);
}

/// Verifies that value of exactly 30 passes through without clamping.
- (void)testIdleTimeoutThirtyPassesThrough {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @30;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.idleTimeoutSeconds);
}

/// Verifies that value of -1 disables idle tracking entirely.
- (void)testIdleTimeoutMinusOneDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @(-1);
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that a large negative value disables idle tracking.
- (void)testIdleTimeoutLargeNegativeDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.idleTimeoutSeconds = @(-9999);
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that idle timeout is forced to 0 when lifecycle events collection is disabled.
- (void)testIdleTimeoutIsZeroWhenCollectingEventsDisabled {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.allowCollectingEventsSet = YES;
    bundleMock.allowCollectingEvents = NO;
    bundleMock.idleTimeoutSeconds = @60;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.idleTimeoutSeconds);
}

/// Verifies that application exit timeout is disabled when key is absent.
- (void)testApplicationExitTimeoutKeyAbsentDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.applicationExitTimeoutSeconds);
}

/// Verifies that application exit timeout uses configured value when within range.
- (void)testApplicationExitTimeoutValidValuePassesThrough {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.applicationExitTimeoutSeconds = @20;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(20, _config.applicationExitTimeoutSeconds);
}

/// Verifies that minimum boundary value (10) passes through unclamped.
- (void)testApplicationExitTimeoutMinBoundaryPassesThrough {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.applicationExitTimeoutSeconds = @10;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(10, _config.applicationExitTimeoutSeconds);
}

/// Verifies that maximum boundary value (30) passes through unclamped.
- (void)testApplicationExitTimeoutMaxBoundaryPassesThrough {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.applicationExitTimeoutSeconds = @30;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.applicationExitTimeoutSeconds);
}

/// Verifies that values below the 10s minimum are clamped up to 10.
- (void)testApplicationExitTimeoutBelowMinimumIsClamped {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.applicationExitTimeoutSeconds = @5;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(10, _config.applicationExitTimeoutSeconds);
}

/// Verifies that values above the 30s maximum are clamped down to 30.
- (void)testApplicationExitTimeoutAboveMaximumIsClamped {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.applicationExitTimeoutSeconds = @60;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(30, _config.applicationExitTimeoutSeconds);
}

/// Verifies that explicit zero disables exit detection.
- (void)testApplicationExitTimeoutZeroDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.applicationExitTimeoutSeconds = @0;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.applicationExitTimeoutSeconds);
}

/// Verifies that negative values disable exit detection.
- (void)testApplicationExitTimeoutNegativeDisablesTracking {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.applicationExitTimeoutSeconds = @(-3);
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.applicationExitTimeoutSeconds);
}

/// Verifies that exit timeout is forced to 0 when lifecycle events collection is disabled.
- (void)testApplicationExitTimeoutIsZeroWhenCollectingEventsDisabled {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.allowCollectingEventsSet = YES;
    bundleMock.allowCollectingEvents = NO;
    bundleMock.applicationExitTimeoutSeconds = @15;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(0, _config.applicationExitTimeoutSeconds);
}

#pragma mark - SDK-801: trim plist string values

/// Regression: Pushwoosh_APPID with trailing newline must be trimmed (the original production bug).
- (void)testAppIdWithTrailingNewlineIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appId = @"58289-245DB\n";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"58289-245DB", _config.appId);
}

/// Verifies leading/trailing whitespace around appId is stripped.
- (void)testAppIdWithLeadingAndTrailingWhitespaceIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appId = @"  12345-ABCDE  ";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"12345-ABCDE", _config.appId);
}

/// Verifies whitespace-only appId becomes nil so native fallback paths trigger.
- (void)testAppIdWhitespaceOnlyBecomesNil {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appId = @"   \n";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertNil(_config.appId);
}

/// Verifies that Pushwoosh_API_TOKEN value is trimmed.
- (void)testApiTokenIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.pushwooshApiToken = @"abc-token-xyz\n";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"abc-token-xyz", _config.pushwooshApiToken);
}

/// Verifies that Pushwoosh_BASEURL value is trimmed.
- (void)testRequestUrlIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.requestUrl = @" https://custom.pushwoosh.com/json/1.3/ ";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"https://custom.pushwoosh.com/json/1.3/", _config.requestUrl);
}

/// Manual #4: Pushwoosh_BASEURL with trailing newline (copy-paste glitch) must be stripped.
- (void)testRequestUrlWithTrailingNewlineIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.requestUrl = @"https://custom.api.pushwoosh.com\n";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"https://custom.api.pushwoosh.com", _config.requestUrl);
}

/// Verifies that whitespace-only Pushwoosh_GRPC_HOST falls back to the default host.
- (void)testGrpcHostEmptyAfterTrimFallsBackToDefault {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.grpcHost = @"   \n";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"grpc.pushwoosh.com", _config.grpcHost);
}

/// Verifies that Pushwoosh_GRPC_HOST with trailing newline is trimmed.
- (void)testGrpcHostWithTrailingNewlineIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.grpcHost = @"grpc.example.com\n";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"grpc.example.com", _config.grpcHost);
}

/// Verifies that "DEBUG\n" still maps to PW_LL_DEBUG (previously fell into default).
- (void)testLogLevelStringWithTrailingNewlineMapsCorrectly {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.logLevel = @"DEBUG\n";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(PW_LL_DEBUG, _config.logLevel);
}

/// Manual #5: "DEBUG " (with trailing space) must still map to PW_LL_DEBUG.
- (void)testLogLevelStringWithTrailingSpaceMapsCorrectly {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.logLevel = @"DEBUG ";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(PW_LL_DEBUG, _config.logLevel);
}

/// Verifies that "MODAL_RICH_MEDIA\n" still maps to PWRichMediaStyleTypeModal.
- (void)testRichMediaStyleWithTrailingNewlineMapsCorrectly {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.richMediaStyle = @"MODAL_RICH_MEDIA\n";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(PWRichMediaStyleTypeModal, _config.richMediaStyle);
}

/// Verifies that a non-string value for a string key is ignored (no crash, nil).
- (void)testNonStringValueForStringKeyIsIgnored {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appIdRaw = @42;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertNil(_config.appId);
}

#pragma mark - SDK-801: extended manual scenarios (#14-#20)

/// Manual #14: tabs around appId are stripped (whitespaceAndNewline includes \t).
- (void)testAppIdWithSurroundingTabsIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appId = @"\t12345-ABCDE\t";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"12345-ABCDE", _config.appId);
}

/// Manual #15: NBSP (U+00A0) around appId is stripped on iOS (whitespaceAndNewlineCharacterSet behaviour).
- (void)testAppIdWithNonBreakingSpaceIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appId = @" 12345-ABCDE ";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"12345-ABCDE", _config.appId);
}

/// Verifies that internal whitespace within appId is preserved (only boundaries are trimmed).
- (void)testAppIdInternalWhitespaceIsPreserved {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appId = @"  ABC DEF  ";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"ABC DEF", _config.appId);
}

/// Manual #16: PW_API_TOKEN with trailing newline is trimmed.
- (void)testApiTokenPlistKeyWithTrailingNewlineIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.apiToken = @"abc-token-xyz\n";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"abc-token-xyz", _config.apiToken);
}

/// Manual #17: Pushwoosh_APPID_Dev with surrounding whitespace is trimmed.
- (void)testAppIdDevWithSurroundingWhitespaceIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appIdDev = @"  DEV-12345  ";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"DEV-12345", _config.appIdDev);
}

/// Verifies that whitespace-only Pushwoosh_APPID_Dev becomes nil.
- (void)testAppIdDevWhitespaceOnlyBecomesNil {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appIdDev = @"\n\t  ";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertNil(_config.appIdDev);
}

/// Manual #18: PW_APP_GROUPS_NAME with trailing newline is trimmed.
- (void)testAppGroupsNameWithTrailingNewlineIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appGroupsName = @"group.com.example.app\n";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"group.com.example.app", _config.appGroupsName);
}

/// Verifies that Pushwoosh_APPNAME with surrounding whitespace is trimmed.
- (void)testAppNameWithSurroundingWhitespaceIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appName = @"  My App Name  ";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"My App Name", _config.appName);
}

/// Manual #19: "MODAL_RICH_MEDIA " (trailing space) maps to PWRichMediaStyleTypeModal.
- (void)testRichMediaStyleWithTrailingSpaceMapsCorrectly {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.richMediaStyle = @"MODAL_RICH_MEDIA ";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqual(PWRichMediaStyleTypeModal, _config.richMediaStyle);
}

/// Manual #20: Pushwoosh_GRPC_HOST with leading newline is trimmed (existing test covers trailing only).
- (void)testGrpcHostWithLeadingNewlineIsTrimmed {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.grpcHost = @"\ngrpc.staging.pushwoosh.com";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"grpc.staging.pushwoosh.com", _config.grpcHost);
}

#pragma mark - SDK-814: reject dotted Pushwoosh_APPID / Pushwoosh_APPID_Dev

/// SDK-814: Verifies that Pushwoosh_APPID containing '.' is rejected at Info.plist read.
- (void)testAppIdWithDotIsRejected {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appId = @"XXXXX-XXXXX.legacy";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertNil(_config.appId);
}

/// SDK-814: Verifies that Pushwoosh_APPID_Dev containing '.' is rejected at Info.plist read.
- (void)testAppIdDevWithDotIsRejected {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appIdDev = @"DEV-XXXXX.legacy";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertNil(_config.appIdDev);
}

/// SDK-814: Sanity check — canonical Pushwoosh_APPID flows through unchanged.
- (void)testAppIdCanonicalAccepted {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.appId = @"XXXXX-XXXXX";
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    XCTAssertEqualObjects(@"XXXXX-XXXXX", _config.appId);
}

@end
