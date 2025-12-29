#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWMedia.h"
#import "PWModalRichMedia.h"
#import "PWLegacyRichMedia.h"
#import "PWConfig.h"

@interface PWMediaTest : XCTestCase

@property (nonatomic, strong) id mockConfig;

@end

@implementation PWMediaTest

- (void)setUp {
    [super setUp];
    self.mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([self.mockConfig config]).andReturn(self.mockConfig);
}

- (void)tearDown {
    [self.mockConfig stopMocking];
    self.mockConfig = nil;
    // Reset to default style
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PWRichMediaPresentationStyle"];
    [super tearDown];
}

#pragma mark - media

- (void)testMediaReturnsSelf {
    Class<PWMedia> result = [PWMedia media];

    XCTAssertEqual(result, [PWMedia class]);
}

#pragma mark - modalRichMedia

- (void)testModalRichMediaReturnsCorrectClass {
    Class<PWModalRichMedia> result = [PWMedia modalRichMedia];

    XCTAssertEqual(result, [PWModalRichMedia class]);
}

#pragma mark - legacyRichMedia

- (void)testLegacyRichMediaReturnsCorrectClass {
    Class<PWLegacyRichMedia> result = [PWMedia legacyRichMedia];

    XCTAssertEqual(result, [PWLegacyRichMedia class]);
}

#pragma mark - setRichMediaPresentationStyle

- (void)testSetRichMediaPresentationStyleModal {
    OCMExpect([(PWConfig *)self.mockConfig setRichMediaStyle:PWRichMediaStyleTypeModal]);

    [PWMedia setRichMediaPresentationStyle:PWRichMediaPresentationStyleModal];

    OCMVerifyAll(self.mockConfig);

    NSInteger savedStyle = [[NSUserDefaults standardUserDefaults] integerForKey:@"PWRichMediaPresentationStyle"];
    XCTAssertEqual(savedStyle, PWRichMediaPresentationStyleModal);
}

- (void)testSetRichMediaPresentationStyleLegacy {
    OCMExpect([(PWConfig *)self.mockConfig setRichMediaStyle:PWRichMediaStyleTypeLegacy]);

    [PWMedia setRichMediaPresentationStyle:PWRichMediaPresentationStyleLegacy];

    OCMVerifyAll(self.mockConfig);

    NSInteger savedStyle = [[NSUserDefaults standardUserDefaults] integerForKey:@"PWRichMediaPresentationStyle"];
    XCTAssertEqual(savedStyle, PWRichMediaPresentationStyleLegacy);
}

#pragma mark - richMediaPresentationStyle

- (void)testRichMediaPresentationStyleReturnsModal {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeModal);

    PWRichMediaPresentationStyle result = [PWMedia richMediaPresentationStyle];

    XCTAssertEqual(result, PWRichMediaPresentationStyleModal);
}

- (void)testRichMediaPresentationStyleReturnsLegacy {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeLegacy);

    PWRichMediaPresentationStyle result = [PWMedia richMediaPresentationStyle];

    XCTAssertEqual(result, PWRichMediaPresentationStyleLegacy);
}

- (void)testRichMediaPresentationStyleReturnsLegacyForDefault {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeDefault);

    PWRichMediaPresentationStyle result = [PWMedia richMediaPresentationStyle];

    XCTAssertEqual(result, PWRichMediaPresentationStyleLegacy);
}

#pragma mark - Integration tests

- (void)testSetAndGetPresentationStyleModal {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeModal);

    [PWMedia setRichMediaPresentationStyle:PWRichMediaPresentationStyleModal];
    PWRichMediaPresentationStyle result = [PWMedia richMediaPresentationStyle];

    XCTAssertEqual(result, PWRichMediaPresentationStyleModal);
}

- (void)testSetAndGetPresentationStyleLegacy {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeLegacy);

    [PWMedia setRichMediaPresentationStyle:PWRichMediaPresentationStyleLegacy];
    PWRichMediaPresentationStyle result = [PWMedia richMediaPresentationStyle];

    XCTAssertEqual(result, PWRichMediaPresentationStyleLegacy);
}

@end
