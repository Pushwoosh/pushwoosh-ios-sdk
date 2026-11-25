#import <XCTest/XCTest.h>
#import <UserNotifications/UserNotifications.h>
#import "PWPushPrimerBuilder.h"
#import "PWPushPrimerPresenter.h"
#import "PWPushPrimerViewController.h"
#import <OCMock/OCMock.h>

@interface PWPushPrimerBuilder (Test)
@property (nonatomic, strong) PWPushPrimerConfig *config;
@end

@interface PWPushPrimerViewController (Test)
@property (nonatomic, strong) UIView *sheet;
+ (BOOL)isGlassSupported;
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

    [self waitForExpectations:@[exp] timeout:5];
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

    [self waitForExpectations:@[exp] timeout:5];
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

    [self waitForExpectations:@[exp] timeout:5];
}

/// Verifies glass is off by default and the builder setter turns it on.
- (void)testGlassDefaultsOff {
    PWPushPrimerBuilder *builder = [PWPushPrimerBuilder new];
    XCTAssertFalse(builder.config.glass);

    PWPushPrimerBuilder *returned = builder.glass(YES);

    XCTAssertEqual(returned, builder);
    XCTAssertTrue(builder.config.glass);
}

/// Verifies the sheet keeps its solid background and plain buttons in every position when glass is off.
- (void)testWithoutGlassSheetKeepsSolidBackgroundInAllPositions {
    for (NSNumber *position in [self allPositions]) {
        PWPushPrimerViewController *controller = [self loadedControllerWithConfig:[self sheetConfigWithPosition:position.integerValue glass:NO]];

        XCTAssertEqualObjects(controller.sheet.backgroundColor, [UIColor redColor], @"position %@", position);
        XCTAssertEqual([self effectViewsInView:controller.sheet].count, (NSUInteger)0, @"position %@", position);
        UIButton *accept = [self buttonWithAction:@"acceptTapped" inController:controller];
        UIButton *decline = [self buttonWithAction:@"declineTapped" inController:controller];
        XCTAssertNil(accept.configuration, @"position %@", position);
        XCTAssertNil(decline.configuration, @"position %@", position);
        XCTAssertEqualObjects(accept.backgroundColor, [UIColor greenColor], @"position %@", position);
    }
}

/// Verifies glass below iOS 26 keeps the solid color, the gradient and plain buttons in every position.
- (void)testGlassFallsBackToColorAndGradientWhenUnsupported {
    id controllerClassMock = OCMClassMock([PWPushPrimerViewController class]);
    OCMStub([controllerClassMock isGlassSupported]).andReturn(NO);

    for (NSNumber *position in [self allPositions]) {
        PWPushPrimerConfig *config = [self sheetConfigWithPosition:position.integerValue glass:YES];
        config.backgroundGradientColors = @[[UIColor orangeColor], [UIColor purpleColor]];
        PWPushPrimerViewController *controller = [self loadedControllerWithConfig:config];

        XCTAssertEqualObjects(controller.sheet.backgroundColor, [UIColor redColor], @"position %@", position);
        XCTAssertTrue([self sheetHasGradient:controller.sheet], @"position %@", position);
        XCTAssertEqual([self effectViewsInView:controller.sheet].count, (NSUInteger)0, @"position %@", position);
        XCTAssertNil([self buttonWithAction:@"acceptTapped" inController:controller].configuration, @"position %@", position);
        XCTAssertNil([self buttonWithAction:@"declineTapped" inController:controller].configuration, @"position %@", position);
    }

    [controllerClassMock stopMocking];
}

/// Verifies glass on iOS 26+ renders a tinted glass sheet without the gradient, a tinted prominent glass accept button and a clear glass decline button in every position.
- (void)testGlassRendersGlassSheetAndButtonsInAllPositions {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        for (NSNumber *position in [self allPositions]) {
            PWPushPrimerConfig *config = [self sheetConfigWithPosition:position.integerValue glass:YES];
            config.backgroundGradientColors = @[[UIColor orangeColor], [UIColor purpleColor]];
            PWPushPrimerViewController *controller = [self loadedControllerWithConfig:config];

            NSArray<UIVisualEffectView *> *effectViews = [self effectViewsInView:controller.sheet];
            XCTAssertEqual(effectViews.count, (NSUInteger)1, @"position %@", position);
            UIGlassEffect *glass = (UIGlassEffect *)effectViews.firstObject.effect;
            XCTAssertTrue([glass isKindOfClass:[UIGlassEffect class]], @"position %@", position);
            XCTAssertEqualObjects(glass.tintColor, [UIColor redColor], @"position %@", position);
            XCTAssertNil(controller.sheet.backgroundColor, @"position %@", position);
            XCTAssertFalse([self sheetHasGradient:controller.sheet], @"position %@", position);

            UIButton *accept = [self buttonWithAction:@"acceptTapped" inController:controller];
            UIButton *decline = [self buttonWithAction:@"declineTapped" inController:controller];
            XCTAssertTrue([accept.configuration.description containsString:@"baseStyle=tintedGlass"], @"position %@: %@", position, accept.configuration);
            XCTAssertEqualObjects(accept.configuration.baseBackgroundColor, [UIColor greenColor], @"position %@", position);
            XCTAssertTrue([decline.configuration.description containsString:@"baseStyle=clearGlass"], @"position %@: %@", position, decline.configuration);
            XCTAssertNil(decline.configuration.baseBackgroundColor, @"position %@", position);
        }
        return;
    }
#endif
    XCTSkip(@"Liquid Glass needs the iOS 26 SDK and runtime");
}

- (NSArray<NSNumber *> *)allPositions {
    return @[@(PWPushPrimerPositionBottom), @(PWPushPrimerPositionTop), @(PWPushPrimerPositionCenter)];
}

- (PWPushPrimerConfig *)sheetConfigWithPosition:(PWPushPrimerPosition)position glass:(BOOL)glass {
    PWPushPrimerConfig *config = [PWPushPrimerConfig new];
    config.style = PWPushPrimerStyleSheet;
    config.position = position;
    config.glass = glass;
    config.backgroundColor = [UIColor redColor];
    config.acceptButtonColor = [UIColor greenColor];
    return config;
}

- (PWPushPrimerViewController *)loadedControllerWithConfig:(PWPushPrimerConfig *)config {
    PWPushPrimerViewController *controller = [[PWPushPrimerViewController alloc] initWithConfig:config onAccept:^{} onDecline:^{}];
    [controller loadViewIfNeeded];
    return controller;
}

- (NSArray<UIVisualEffectView *> *)effectViewsInView:(UIView *)view {
    NSMutableArray<UIVisualEffectView *> *found = [NSMutableArray array];
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [found addObject:(UIVisualEffectView *)subview];
        }
        if (![subview isKindOfClass:[UIButton class]]) {
            [found addObjectsFromArray:[self effectViewsInView:subview]];
        }
    }
    return found;
}

- (UIButton *)buttonWithAction:(NSString *)action inController:(PWPushPrimerViewController *)controller {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:controller.view];
    while (queue.count > 0) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([view isKindOfClass:[UIButton class]]
            && [[(UIButton *)view actionsForTarget:controller forControlEvent:UIControlEventTouchUpInside] containsObject:action]) {
            return (UIButton *)view;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return nil;
}

- (BOOL)sheetHasGradient:(UIView *)sheet {
    for (CALayer *layer in sheet.layer.sublayers) {
        if ([layer isKindOfClass:[CAGradientLayer class]]) {
            return YES;
        }
    }
    return NO;
}

@end
