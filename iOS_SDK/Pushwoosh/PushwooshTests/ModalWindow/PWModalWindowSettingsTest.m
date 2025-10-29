#import <XCTest/XCTest.h>
#import "PWModalWindowSettings.h"

@interface PWModalWindowSettingsTest : XCTestCase

@end

@implementation PWModalWindowSettingsTest

- (void)testSharedSettingsReturnsSameInstance {
    PWModalWindowSettings *instance1 = [PWModalWindowSettings sharedSettings];
    PWModalWindowSettings *instance2 = [PWModalWindowSettings sharedSettings];

    XCTAssertNotNil(instance1);
    XCTAssertNotNil(instance2);
    XCTAssertEqual(instance1, instance2);
}

- (void)testDefaultModalWindowPosition {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];

    XCTAssertEqual(settings.modalWindowPosition, PWModalWindowPositionDefault);
}

- (void)testDefaultDismissSwipeDirections {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];

    XCTAssertNotNil(settings.dismissSwipeDirections);
    XCTAssertEqual(settings.dismissSwipeDirections.count, 1);
    XCTAssertEqualObjects(settings.dismissSwipeDirections[0], @(PWSwipeDismissNone));
}

- (void)testDefaultHapticFeedbackType {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];

    XCTAssertEqual(settings.hapticFeedbackType, PWHapticFeedbackNone);
}

- (void)testDefaultPresentAnimation {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];

    XCTAssertEqual(settings.presentAnimation, PWAnimationPresentFromBottom);
}

- (void)testDefaultDismissAnimation {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];

    XCTAssertEqual(settings.dismissAnimation, PWAnimationCurveEaseInOut);
}

- (void)testDefaultCornerType {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];

    XCTAssertEqual(settings.cornerType, PWCornerTypeNone);
}

- (void)testDefaultCornerRadius {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];

    XCTAssertEqual(settings.cornerRadius, 0);
}

- (void)testSetModalWindowPosition {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    ModalWindowPosition originalValue = settings.modalWindowPosition;

    settings.modalWindowPosition = PWModalWindowPositionCenter;
    XCTAssertEqual(settings.modalWindowPosition, PWModalWindowPositionCenter);

    settings.modalWindowPosition = originalValue;
}

- (void)testSetDismissSwipeDirections {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    NSArray *originalValue = settings.dismissSwipeDirections;

    NSArray *newDirections = @[@(PWSwipeDismissUp), @(PWSwipeDismissDown)];
    settings.dismissSwipeDirections = newDirections;
    XCTAssertEqualObjects(settings.dismissSwipeDirections, newDirections);

    settings.dismissSwipeDirections = originalValue;
}

- (void)testSetHapticFeedbackType {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    HapticFeedbackType originalValue = settings.hapticFeedbackType;

    settings.hapticFeedbackType = PWHapticFeedbackLight;
    XCTAssertEqual(settings.hapticFeedbackType, PWHapticFeedbackLight);

    settings.hapticFeedbackType = originalValue;
}

- (void)testSetPresentAnimation {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    PresentModalWindowAnimation originalValue = settings.presentAnimation;

    settings.presentAnimation = PWAnimationPresentFromTop;
    XCTAssertEqual(settings.presentAnimation, PWAnimationPresentFromTop);

    settings.presentAnimation = originalValue;
}

- (void)testSetDismissAnimation {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    DismissModalWindowAnimation originalValue = settings.dismissAnimation;

    settings.dismissAnimation = PWAnimationDismissUp;
    XCTAssertEqual(settings.dismissAnimation, PWAnimationDismissUp);

    settings.dismissAnimation = originalValue;
}

- (void)testSetCornerType {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    CornerType originalValue = settings.cornerType;

    settings.cornerType = PWCornerTypeTopLeft;
    XCTAssertEqual(settings.cornerType, PWCornerTypeTopLeft);

    settings.cornerType = originalValue;
}

- (void)testSetCornerRadius {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    CGFloat originalValue = settings.cornerRadius;

    settings.cornerRadius = 10.0;
    XCTAssertEqual(settings.cornerRadius, 10.0);

    settings.cornerRadius = originalValue;
}

- (void)testSetDismissSwipeDirectionsWithEmptyArray {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    NSArray *originalValue = settings.dismissSwipeDirections;

    NSArray *emptyArray = @[];
    settings.dismissSwipeDirections = emptyArray;
    XCTAssertEqualObjects(settings.dismissSwipeDirections, emptyArray);

    settings.dismissSwipeDirections = originalValue;
}

- (void)testSetDismissSwipeDirectionsWithMultipleValues {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    NSArray *originalValue = settings.dismissSwipeDirections;

    NSArray *multipleDirections = @[@(PWSwipeDismissUp), @(PWSwipeDismissDown), @(PWSwipeDismissLeft), @(PWSwipeDismissRight)];
    settings.dismissSwipeDirections = multipleDirections;
    XCTAssertEqualObjects(settings.dismissSwipeDirections, multipleDirections);

    settings.dismissSwipeDirections = originalValue;
}

- (void)testSetCornerRadiusWithLargeValue {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    CGFloat originalValue = settings.cornerRadius;

    settings.cornerRadius = 100.0;
    XCTAssertEqual(settings.cornerRadius, 100.0);

    settings.cornerRadius = originalValue;
}

- (void)testSetCornerRadiusWithZero {
    PWModalWindowSettings *settings = [PWModalWindowSettings sharedSettings];
    CGFloat originalValue = settings.cornerRadius;

    settings.cornerRadius = 0.0;
    XCTAssertEqual(settings.cornerRadius, 0.0);

    settings.cornerRadius = originalValue;
}

@end
