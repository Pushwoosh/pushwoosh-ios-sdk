#import <XCTest/XCTest.h>
#import <UserNotifications/UserNotifications.h>
#import "PWPushPrimerBuilder.h"
#import "PWPushPrimerPresenter.h"

@interface PWPushPrimerBuilder (Test)
@property (nonatomic, strong) PWPushPrimerConfig *config;
@end

@interface PWPushPrimerTest : XCTestCase
@end

@implementation PWPushPrimerTest

/// Verifies the fluent chain returns the same builder and accumulates config values.
- (void)testFluentChainAccumulatesConfig {
    PWPushPrimerBuilder *builder = [PWPushPrimerBuilder new];

    PWPushPrimerBuilder *returned = builder
        .style(PWPushPrimerStyleSheet)
        .title(@"Title")
        .message(@"Message")
        .acceptButton(@"Yes")
        .declineButton(@"No")
        .cornerRadius(12);

    XCTAssertEqual(returned, builder);
    XCTAssertEqual(builder.config.style, PWPushPrimerStyleSheet);
    XCTAssertEqualObjects(builder.config.title, @"Title");
    XCTAssertEqualObjects(builder.config.message, @"Message");
    XCTAssertEqualObjects(builder.config.acceptButtonTitle, @"Yes");
    XCTAssertEqualObjects(builder.config.declineButtonTitle, @"No");
    XCTAssertEqual(builder.config.cornerRadius, 12);
    XCTAssertTrue(builder.config.cornerRadiusSet);
}

/// Verifies the builder defaults to alert style.
- (void)testDefaultStyleIsAlert {
    PWPushPrimerBuilder *builder = [PWPushPrimerBuilder new];
    XCTAssertEqual(builder.config.style, PWPushPrimerStyleAlert);
}

/// Verifies the builder defaults fallbackToSettings to YES.
- (void)testFallbackToSettingsDefaultsYes {
    PWPushPrimerBuilder *builder = [PWPushPrimerBuilder new];
    XCTAssertTrue(builder.config.fallbackToSettings);
    builder.fallbackToSettings(NO);
    XCTAssertFalse(builder.config.fallbackToSettings);
}

/// Verifies authorized status suppresses the primer without showing UI.
- (void)testAuthorizedSuppresses {
    PWPushPrimerPresenter *presenter = [PWPushPrimerPresenter new];
    PWPushPrimerConfig *config = [PWPushPrimerConfig new];
    XCTestExpectation *exp = [self expectationWithDescription:@"outcome"];

    [presenter handleStatus:UNAuthorizationStatusAuthorized config:config completion:^(PWPushPrimerOutcome outcome) {
        XCTAssertEqual(outcome, PWPushPrimerOutcomeSuppressed);
        [exp fulfill];
    }];

    [self waitForExpectations:@[exp] timeout:1.0];
}

/// Verifies provisional status suppresses the primer without showing UI.
- (void)testProvisionalSuppresses {
    PWPushPrimerPresenter *presenter = [PWPushPrimerPresenter new];
    PWPushPrimerConfig *config = [PWPushPrimerConfig new];
    XCTestExpectation *exp = [self expectationWithDescription:@"outcome"];

    [presenter handleStatus:UNAuthorizationStatusProvisional config:config completion:^(PWPushPrimerOutcome outcome) {
        XCTAssertEqual(outcome, PWPushPrimerOutcomeSuppressed);
        [exp fulfill];
    }];

    [self waitForExpectations:@[exp] timeout:1.0];
}

/// Verifies denied status with fallbackToSettings disabled suppresses the primer.
- (void)testDeniedWithoutFallbackSuppresses {
    PWPushPrimerPresenter *presenter = [PWPushPrimerPresenter new];
    PWPushPrimerConfig *config = [PWPushPrimerConfig new];
    config.fallbackToSettings = NO;
    XCTestExpectation *exp = [self expectationWithDescription:@"outcome"];

    [presenter handleStatus:UNAuthorizationStatusDenied config:config completion:^(PWPushPrimerOutcome outcome) {
        XCTAssertEqual(outcome, PWPushPrimerOutcomeSuppressed);
        [exp fulfill];
    }];

    [self waitForExpectations:@[exp] timeout:1.0];
}

@end
