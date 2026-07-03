#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWModalWindow.h"
#import "PWModalWindowSettings.h"
#import "PWResource.h"
#import "PWRichMediaConfig.h"

@interface PWModalWindow (Test)
@property (nonatomic) PWModalWindowSettings *settings;
- (ModalWindowPosition)effectiveModalWindowPositionForResource:(PWResource *)resource;
- (PresentModalWindowAnimation)effectivePresentAnimationForResource:(PWResource *)resource;
- (DismissModalWindowAnimation)effectiveDismissAnimationForResource:(PWResource *)resource;
- (NSArray<NSNumber *> *)effectiveSwipeDirectionsForResource:(PWResource *)resource;
- (NSTimeInterval)effectiveAnimationDurationForResource:(PWResource *)resource fallback:(NSTimeInterval)fallback;
- (DismissModalWindowAnimation)animationDirectionForSwipeDirection:(UISwipeGestureRecognizerDirection)direction;
- (BOOL)shouldShowCloseButtonForResource:(PWResource *)resource;
@end

@interface PWModalWindowTest : XCTestCase
@property (nonatomic, strong) PWModalWindow *modalWindow;
@property (nonatomic, strong) PWModalWindowSettings *settings;
@property (nonatomic, strong) PWResource *resourceMock;
@property (nonatomic, strong) PWRichMediaConfig *configMock;
@end

@implementation PWModalWindowTest

- (void)setUp {
    [super setUp];
    self.modalWindow = [[PWModalWindow alloc] initWithFrame:CGRectZero];

    self.settings = [PWModalWindowSettings new];
    self.settings.modalWindowPosition = PWModalWindowPositionDefault;
    self.settings.presentAnimation = PWAnimationPresentFadeIn;
    self.settings.dismissAnimation = PWAnimationDismissFadeOut;
    self.settings.dismissSwipeDirections = @[@(PWSwipeDismissNone)];
    self.settings.animationDuration = 0;
    self.settings.autoCloseInterval = 0;
    self.modalWindow.settings = self.settings;

    self.configMock = OCMClassMock([PWRichMediaConfig class]);
    self.resourceMock = OCMClassMock([PWResource class]);
    OCMStub([self.resourceMock readConfig]);
    OCMStub([self.resourceMock config]).andReturn(self.configMock);
}

- (void)tearDown {
    [(id)self.resourceMock stopMocking];
    [(id)self.configMock stopMocking];
    self.resourceMock = nil;
    self.configMock = nil;
    self.settings = nil;
    self.modalWindow = nil;
    [super tearDown];
}

#pragma mark - effectivePresentAnimationForResource

/// Returns the resource present animation when the config specifies a non-Unset value.
- (void)testEffectivePresentAnimationUsesResourceWhenSet {
    OCMStub([self.resourceMock presentAnimation]).andReturn(PWAnimationPresentDropDown);
    XCTAssertEqual([self.modalWindow effectivePresentAnimationForResource:self.resourceMock], PWAnimationPresentDropDown);
}

/// Falls back to the global settings value when the resource leaves the present animation Unset.
- (void)testEffectivePresentAnimationFallsBackToSettingsWhenUnset {
    OCMStub([self.resourceMock presentAnimation]).andReturn(PWAnimationPresentUnset);
    XCTAssertEqual([self.modalWindow effectivePresentAnimationForResource:self.resourceMock], PWAnimationPresentFadeIn);
}

/// Falls back to settings when the resource has no parsed config.
- (void)testEffectivePresentAnimationFallsBackToSettingsWhenNoConfig {
    PWResource *resourceNoConfig = OCMClassMock([PWResource class]);
    OCMStub([resourceNoConfig readConfig]);
    OCMStub([resourceNoConfig config]).andReturn(nil);
    OCMStub([resourceNoConfig presentAnimation]).andReturn(PWAnimationPresentDropDown);
    XCTAssertEqual([self.modalWindow effectivePresentAnimationForResource:resourceNoConfig], PWAnimationPresentFadeIn);
    [(id)resourceNoConfig stopMocking];
}

#pragma mark - effectiveDismissAnimationForResource

/// Returns the resource dismiss animation when the config specifies a non-Unset value.
- (void)testEffectiveDismissAnimationUsesResourceWhenSet {
    OCMStub([self.resourceMock dismissAnimation]).andReturn(PWAnimationDismissSlideLeft);
    XCTAssertEqual([self.modalWindow effectiveDismissAnimationForResource:self.resourceMock], PWAnimationDismissSlideLeft);
}

/// Falls back to the global settings value when the resource leaves the dismiss animation Unset.
- (void)testEffectiveDismissAnimationFallsBackToSettingsWhenUnset {
    OCMStub([self.resourceMock dismissAnimation]).andReturn(PWAnimationDismissUnset);
    XCTAssertEqual([self.modalWindow effectiveDismissAnimationForResource:self.resourceMock], PWAnimationDismissFadeOut);
}

#pragma mark - effectiveModalWindowPositionForResource

/// Returns the resource position when the config specifies a non-Default value.
- (void)testEffectivePositionUsesResourceWhenSet {
    OCMStub([self.resourceMock position]).andReturn(PWModalWindowPositionBottom);
    XCTAssertEqual([self.modalWindow effectiveModalWindowPositionForResource:self.resourceMock], PWModalWindowPositionBottom);
}

/// Falls back to settings when the resource position is Default.
- (void)testEffectivePositionFallsBackToSettingsWhenDefault {
    OCMStub([self.resourceMock position]).andReturn(PWModalWindowPositionDefault);
    self.settings.modalWindowPosition = PWModalWindowPositionTop;
    XCTAssertEqual([self.modalWindow effectiveModalWindowPositionForResource:self.resourceMock], PWModalWindowPositionTop);
}

#pragma mark - effectiveSwipeDirectionsForResource

/// Returns the resource swipe directions when the config provides at least one.
- (void)testEffectiveSwipeDirectionsUsesResourceWhenNonEmpty {
    OCMStub([self.resourceMock swipeToDismiss]).andReturn(@[@(PWSwipeDismissLeft)]);
    XCTAssertEqualObjects([self.modalWindow effectiveSwipeDirectionsForResource:self.resourceMock], @[@(PWSwipeDismissLeft)]);
}

/// Falls back to settings when the resource provides no swipe directions.
- (void)testEffectiveSwipeDirectionsFallsBackToSettingsWhenEmpty {
    OCMStub([self.resourceMock swipeToDismiss]).andReturn(@[]);
    self.settings.dismissSwipeDirections = @[@(PWSwipeDismissDown)];
    XCTAssertEqualObjects([self.modalWindow effectiveSwipeDirectionsForResource:self.resourceMock], @[@(PWSwipeDismissDown)]);
}

#pragma mark - effectiveAnimationDurationForResource:fallback:

/// Resource duration takes priority over settings and fallback when positive.
- (void)testEffectiveDurationUsesResourceWhenPositive {
    OCMStub([self.resourceMock animationDuration]).andReturn(0.5);
    self.settings.animationDuration = 0.8;
    XCTAssertEqualWithAccuracy([self.modalWindow effectiveAnimationDurationForResource:self.resourceMock fallback:0.3], 0.5, 0.0001);
}

/// Uses the settings duration when the resource does not specify one.
- (void)testEffectiveDurationFallsBackToSettings {
    OCMStub([self.resourceMock animationDuration]).andReturn(0.0);
    self.settings.animationDuration = 0.8;
    XCTAssertEqualWithAccuracy([self.modalWindow effectiveAnimationDurationForResource:self.resourceMock fallback:0.3], 0.8, 0.0001);
}

/// Uses the fallback when neither resource nor settings specify a duration.
- (void)testEffectiveDurationUsesFallbackWhenNoneSet {
    OCMStub([self.resourceMock animationDuration]).andReturn(0.0);
    self.settings.animationDuration = 0.0;
    XCTAssertEqualWithAccuracy([self.modalWindow effectiveAnimationDurationForResource:self.resourceMock fallback:0.3], 0.3, 0.0001);
}

#pragma mark - animationDirectionForSwipeDirection

/// Each swipe direction maps to the matching slide-out dismiss animation.
- (void)testSwipeDirectionMapsToDismissAnimation {
    XCTAssertEqual([self.modalWindow animationDirectionForSwipeDirection:UISwipeGestureRecognizerDirectionUp], PWAnimationDismissSlideUp);
    XCTAssertEqual([self.modalWindow animationDirectionForSwipeDirection:UISwipeGestureRecognizerDirectionDown], PWAnimationDismissSlideDown);
    XCTAssertEqual([self.modalWindow animationDirectionForSwipeDirection:UISwipeGestureRecognizerDirectionLeft], PWAnimationDismissSlideLeft);
    XCTAssertEqual([self.modalWindow animationDirectionForSwipeDirection:UISwipeGestureRecognizerDirectionRight], PWAnimationDismissSlideRight);
}

#pragma mark - shouldShowCloseButtonForResource

/// Shows the close button for a center-positioned resource that requests it.
- (void)testShouldShowCloseButtonForCenterPosition {
    OCMStub([self.resourceMock closeButton]).andReturn(YES);
    OCMStub([self.resourceMock position]).andReturn(PWModalWindowPositionCenter);
    XCTAssertTrue([self.modalWindow shouldShowCloseButtonForResource:self.resourceMock]);
}

/// Hides the close button for non-center positions even when requested.
- (void)testShouldNotShowCloseButtonForBottomPosition {
    OCMStub([self.resourceMock closeButton]).andReturn(YES);
    OCMStub([self.resourceMock position]).andReturn(PWModalWindowPositionBottom);
    XCTAssertFalse([self.modalWindow shouldShowCloseButtonForResource:self.resourceMock]);
}

/// Hides the close button when the resource does not request one.
- (void)testShouldNotShowCloseButtonWhenResourceHasNone {
    OCMStub([self.resourceMock closeButton]).andReturn(NO);
    OCMStub([self.resourceMock position]).andReturn(PWModalWindowPositionCenter);
    XCTAssertFalse([self.modalWindow shouldShowCloseButtonForResource:self.resourceMock]);
}

#pragma mark - closeModalWindowAfter

/// Persists the auto-close interval onto the settings.
- (void)testCloseModalWindowAfterStoresInterval {
    [self.modalWindow closeModalWindowAfter:7.5];
    XCTAssertEqual(self.settings.autoCloseInterval, 7.5);
}

@end
