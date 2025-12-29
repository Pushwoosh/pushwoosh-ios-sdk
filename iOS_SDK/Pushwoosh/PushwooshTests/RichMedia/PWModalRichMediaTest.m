#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWModalRichMedia.h"
#import "PWModalWindowConfiguration.h"
#import "PWRichMediaManager.h"
#import "PWRichMedia.h"

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
                                              presentAnimation:PWAnimationPresentFromBottom
                                              dismissAnimation:PWAnimationDismissDown]);

    [PWModalRichMedia configureWithPosition:PWModalWindowPositionBottom
                           presentAnimation:PWAnimationPresentFromBottom
                           dismissAnimation:PWAnimationDismissDown];

    OCMVerifyAll(self.mockConfiguration);
}

- (void)testConfigureWithPositionCenter {
    OCMExpect([self.mockConfiguration configureModalWindowWith:PWModalWindowPositionCenter
                                              presentAnimation:PWAnimationPresentFromTop
                                              dismissAnimation:PWAnimationDismissUp]);

    [PWModalRichMedia configureWithPosition:PWModalWindowPositionCenter
                           presentAnimation:PWAnimationPresentFromTop
                           dismissAnimation:PWAnimationDismissUp];

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

@end
