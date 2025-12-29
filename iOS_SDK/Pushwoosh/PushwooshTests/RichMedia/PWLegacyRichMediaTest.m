#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWLegacyRichMedia.h"
#import "PWRichMediaManager.h"
#import "PWRichMedia.h"

@interface PWLegacyRichMediaTest : XCTestCase

@property (nonatomic, strong) id mockManager;

@end

@implementation PWLegacyRichMediaTest

- (void)setUp {
    [super setUp];
    self.mockManager = OCMClassMock([PWRichMediaManager class]);
    OCMStub([self.mockManager sharedManager]).andReturn(self.mockManager);
}

- (void)tearDown {
    [self.mockManager stopMocking];
    self.mockManager = nil;
    [super tearDown];
}

#pragma mark - legacyRichMedia

- (void)testLegacyRichMediaReturnsSelf {
    Class<PWLegacyRichMedia> result = [PWLegacyRichMedia legacyRichMedia];

    XCTAssertEqual(result, [PWLegacyRichMedia class]);
}

#pragma mark - delegate

- (void)testGetDelegate {
    id<PWRichMediaPresentingDelegate> mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([self.mockManager delegate]).andReturn(mockDelegate);

    id<PWRichMediaPresentingDelegate> result = [PWLegacyRichMedia getDelegate];

    XCTAssertEqual(result, mockDelegate);
}

- (void)testGetDelegateReturnsNilWhenNotSet {
    OCMStub([self.mockManager delegate]).andReturn(nil);

    id<PWRichMediaPresentingDelegate> result = [PWLegacyRichMedia getDelegate];

    XCTAssertNil(result);
}

- (void)testSetDelegate {
    id<PWRichMediaPresentingDelegate> mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));

    OCMExpect([self.mockManager setDelegate:mockDelegate]);

    [PWLegacyRichMedia setDelegate:mockDelegate];

    OCMVerifyAll(self.mockManager);
}

- (void)testSetDelegateNil {
    OCMExpect([self.mockManager setDelegate:nil]);

    [PWLegacyRichMedia setDelegate:nil];

    OCMVerifyAll(self.mockManager);
}

#pragma mark - presentRichMedia

- (void)testPresentRichMedia {
    id mockRichMedia = OCMClassMock([PWRichMedia class]);

    OCMExpect([self.mockManager presentRichMedia:mockRichMedia]);

    [PWLegacyRichMedia presentRichMedia:mockRichMedia];

    OCMVerifyAll(self.mockManager);
    [mockRichMedia stopMocking];
}

@end
