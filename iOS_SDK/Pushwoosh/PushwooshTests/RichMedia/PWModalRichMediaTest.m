#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWModalRichMedia.h"
#import "PWModalWindowConfiguration.h"
#import "PWRichMediaManager.h"
#import "PWRichMedia.h"
#import "PWRichMediaConfig.h"

@interface PWRichMediaConfig (Test)
- (void)parseStyleSettings:(NSDictionary *)styleDict;
@end

@interface PWModalRichMediaTest : XCTestCase

@property (nonatomic, strong) id mockConfiguration;
@property (nonatomic, strong) id mockManager;

@end

@implementation PWModalRichMediaTest

- (void)setUp {
    [super setUp];
    self.mockConfiguration = OCMClassMock([PWModalWindowConfiguration class]);
    self.mockManager = OCMClassMock([PWRichMediaManager class]);

    OCMStub([self.mockConfiguration shared]).andReturn(self.mockConfiguration);
    OCMStub([self.mockManager sharedManager]).andReturn(self.mockManager);
}

- (void)tearDown {
    [self.mockConfiguration stopMocking];
    [self.mockManager stopMocking];
    self.mockConfiguration = nil;
    self.mockManager = nil;
    [super tearDown];
}

#pragma mark - modalRichMedia

- (void)testModalRichMediaReturnsSelf {
    Class<PWModalRichMedia> result = [PWModalRichMedia modalRichMedia];

    XCTAssertEqual(result, [PWModalRichMedia class]);
}

#pragma mark - configureWithPosition

- (void)testConfigureWithPositionCallsConfiguration {
    OCMExpect([self.mockConfiguration configureModalWindowWith:PWModalWindowPositionBottom
                                              presentAnimation:PWAnimationPresentSlideUp
                                              dismissAnimation:PWAnimationDismissSlideDown]);

    [PWModalRichMedia configureWithPosition:PWModalWindowPositionBottom
                           presentAnimation:PWAnimationPresentSlideUp
                           dismissAnimation:PWAnimationDismissSlideDown];

    OCMVerifyAll(self.mockConfiguration);
}

- (void)testConfigureWithPositionCenter {
    OCMExpect([self.mockConfiguration configureModalWindowWith:PWModalWindowPositionCenter
                                              presentAnimation:PWAnimationPresentDropDown
                                              dismissAnimation:PWAnimationDismissSlideUp]);

    [PWModalRichMedia configureWithPosition:PWModalWindowPositionCenter
                           presentAnimation:PWAnimationPresentDropDown
                           dismissAnimation:PWAnimationDismissSlideUp];

    OCMVerifyAll(self.mockConfiguration);
}

#pragma mark - setDismissSwipeDirections

- (void)testSetDismissSwipeDirections {
    NSArray *directions = @[@(PWSwipeDismissDown), @(PWSwipeDismissUp)];

    OCMExpect([self.mockConfiguration setDismissSwipeDirections:directions]);

    [PWModalRichMedia setDismissSwipeDirections:directions];

    OCMVerifyAll(self.mockConfiguration);
}

- (void)testSetDismissSwipeDirectionsWithEmptyArray {
    NSArray *directions = @[];

    OCMExpect([self.mockConfiguration setDismissSwipeDirections:directions]);

    [PWModalRichMedia setDismissSwipeDirections:directions];

    OCMVerifyAll(self.mockConfiguration);
}

#pragma mark - setHapticFeedbackType

- (void)testSetHapticFeedbackType {
    OCMExpect([self.mockConfiguration setPresentHapticFeedbackType:PWHapticFeedbackMedium]);

    [PWModalRichMedia setHapticFeedbackType:PWHapticFeedbackMedium];

    OCMVerifyAll(self.mockConfiguration);
}

- (void)testSetHapticFeedbackTypeNone {
    OCMExpect([self.mockConfiguration setPresentHapticFeedbackType:PWHapticFeedbackNone]);

    [PWModalRichMedia setHapticFeedbackType:PWHapticFeedbackNone];

    OCMVerifyAll(self.mockConfiguration);
}

#pragma mark - setCornerType

- (void)testSetCornerTypeWithRadius {
    CornerType cornerType = PWCornerTypeTopLeft | PWCornerTypeTopRight;
    CGFloat radius = 16.0;

    OCMExpect([self.mockConfiguration setCornerType:cornerType withRadius:radius]);

    [PWModalRichMedia setCornerType:cornerType withRadius:radius];

    OCMVerifyAll(self.mockConfiguration);
}

- (void)testSetCornerTypeWithZeroRadius {
    OCMExpect([self.mockConfiguration setCornerType:PWCornerTypeNone withRadius:0]);

    [PWModalRichMedia setCornerType:PWCornerTypeNone withRadius:0];

    OCMVerifyAll(self.mockConfiguration);
}

#pragma mark - closeAfter

- (void)testCloseAfter {
    NSTimeInterval interval = 10.0;

    OCMExpect([self.mockConfiguration closeModalWindowAfter:interval]);

    [PWModalRichMedia closeAfter:interval];

    OCMVerifyAll(self.mockConfiguration);
}

- (void)testCloseAfterZero {
    OCMExpect([self.mockConfiguration closeModalWindowAfter:0]);

    [PWModalRichMedia closeAfter:0];

    OCMVerifyAll(self.mockConfiguration);
}

#pragma mark - setAnimationDuration

- (void)testSetAnimationDuration {
    OCMExpect([self.mockConfiguration setAnimationDuration:0.5]);

    [PWModalRichMedia setAnimationDuration:0.5];

    OCMVerifyAll(self.mockConfiguration);
}

- (void)testSetAnimationDurationZero {
    OCMExpect([self.mockConfiguration setAnimationDuration:0]);

    [PWModalRichMedia setAnimationDuration:0];

    OCMVerifyAll(self.mockConfiguration);
}

#pragma mark - delegate

- (void)testGetDelegate {
    id<PWRichMediaPresentingDelegate> mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([self.mockManager delegate]).andReturn(mockDelegate);

    id<PWRichMediaPresentingDelegate> result = [PWModalRichMedia getDelegate];

    XCTAssertEqual(result, mockDelegate);
}

- (void)testGetDelegateReturnsNilWhenNotSet {
    OCMStub([self.mockManager delegate]).andReturn(nil);

    id<PWRichMediaPresentingDelegate> result = [PWModalRichMedia getDelegate];

    XCTAssertNil(result);
}

- (void)testSetDelegate {
    id<PWRichMediaPresentingDelegate> mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));

    OCMExpect([self.mockManager setDelegate:mockDelegate]);

    [PWModalRichMedia setDelegate:mockDelegate];

    OCMVerifyAll(self.mockManager);
}

- (void)testSetDelegateNil {
    OCMExpect([self.mockManager setDelegate:nil]);

    [PWModalRichMedia setDelegate:nil];

    OCMVerifyAll(self.mockManager);
}

#pragma mark - presentRichMedia

- (void)testPresentRichMedia {
    id mockRichMedia = OCMClassMock([PWRichMedia class]);

    OCMExpect([self.mockManager presentRichMedia:mockRichMedia]);

    [PWModalRichMedia presentRichMedia:mockRichMedia];

    OCMVerifyAll(self.mockManager);
    [mockRichMedia stopMocking];
}

#pragma mark - presentAnimationFromString (canon: direction of travel)

- (void)testPresentAnimationUpMapsToSlideUp {
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@"up"], PWAnimationPresentSlideUp);
}

- (void)testPresentAnimationDownMapsToDropDown {
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@"down"], PWAnimationPresentDropDown);
}

- (void)testPresentAnimationLeftRightMapDirectly {
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@"left"], PWAnimationPresentSlideFromLeft);
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@"right"], PWAnimationPresentSlideFromRight);
}

- (void)testPresentAnimationFadeAndNoneRecognized {
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@"fade_in"], PWAnimationPresentFadeIn);
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@"none"], PWAnimationPresentNone);
}

- (void)testPresentAnimationUnknownEmptyNilMapToUnset {
    NSString *nilString = nil;
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@"wobble"], PWAnimationPresentUnset);
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@""], PWAnimationPresentUnset);
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:nilString], PWAnimationPresentUnset);
}

#pragma mark - dismissAnimationFromString

- (void)testDismissAnimationDirectionsMapDirectly {
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@"up"], PWAnimationDismissSlideUp);
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@"down"], PWAnimationDismissSlideDown);
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@"left"], PWAnimationDismissSlideLeft);
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@"right"], PWAnimationDismissSlideRight);
}

- (void)testDismissAnimationFadeAndNoneRecognized {
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@"fade_out"], PWAnimationDismissFadeOut);
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@"none"], PWAnimationDismissNone);
}

- (void)testDismissAnimationUnknownEmptyNilMapToUnset {
    NSString *nilString = nil;
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@"wobble"], PWAnimationDismissUnset);
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@""], PWAnimationDismissUnset);
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:nilString], PWAnimationDismissUnset);
}

#pragma mark - animation_duration parsing (ms → s)

- (void)testParseAnimationDurationConvertsMillisecondsToSeconds {
    PWRichMediaConfig *config = [PWRichMediaConfig new];

    [config parseStyleSettings:@{@"animation_duration": @500}];

    XCTAssertEqualWithAccuracy(config.animationDuration, 0.5, 0.0001);
}

- (void)testParseAnimationDurationIgnoresLegacyDurationKey {
    PWRichMediaConfig *config = [PWRichMediaConfig new];

    [config parseStyleSettings:@{@"duration": @1000}];

    XCTAssertEqual(config.animationDuration, 0);
}

- (void)testParseAnimationDurationAbsentLeavesZero {
    PWRichMediaConfig *config = [PWRichMediaConfig new];

    [config parseStyleSettings:@{}];

    XCTAssertEqual(config.animationDuration, 0);
}

#pragma mark - case-insensitive parsing (Android parity)

- (void)testPresentAnimationParsingIsCaseInsensitive {
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@"UP"], PWAnimationPresentSlideUp);
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@"Fade_In"], PWAnimationPresentFadeIn);
    XCTAssertEqual([PWRichMediaConfig presentAnimationFromString:@"NONE"], PWAnimationPresentNone);
}

- (void)testDismissAnimationParsingIsCaseInsensitive {
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@"DOWN"], PWAnimationDismissSlideDown);
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@"Fade_Out"], PWAnimationDismissFadeOut);
    XCTAssertEqual([PWRichMediaConfig dismissAnimationFromString:@"None"], PWAnimationDismissNone);
}

- (void)testPositionParsingIsCaseInsensitive {
    XCTAssertEqual([PWRichMediaConfig positionFromString:@"FULLSCREEN"], PWModalWindowPositionFullScreen);
    XCTAssertEqual([PWRichMediaConfig positionFromString:@"Center"], PWModalWindowPositionCenter);
    XCTAssertEqual([PWRichMediaConfig positionFromString:@"Bottom"], PWModalWindowPositionBottom);
}

- (void)testSwipeDirectionParsingIsCaseInsensitive {
    PWRichMediaConfig *config = [PWRichMediaConfig new];

    [config parseStyleSettings:@{@"swipe_to_dismiss": @[@"Down", @"UP"]}];

    XCTAssertEqual(config.swipeToDismiss.count, 2);
    XCTAssertTrue([config.swipeToDismiss containsObject:@(PWSwipeDismissDown)]);
    XCTAssertTrue([config.swipeToDismiss containsObject:@(PWSwipeDismissUp)]);
}

@end
