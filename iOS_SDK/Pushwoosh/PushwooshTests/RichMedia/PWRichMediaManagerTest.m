#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWRichMediaManager.h"
#import "PWModalWindowConfiguration.h"
#import "PWMessageViewController.h"
#import "PWConfig.h"
#import "PWRichMedia.h"

@interface PWRichMediaManager (Test)

- (BOOL)shouldPresentRichMedia:(PWRichMedia *)richMedia;

@end

@interface PWRichMediaManagerTest : XCTestCase

@property (nonatomic, strong) PWRichMediaManager *manager;
@property (nonatomic, strong) id mockConfiguration;
@property (nonatomic, strong) id mockMessageViewController;
@property (nonatomic, strong) id mockConfig;
@property (nonatomic, strong) id mockRichMedia;

@end

@implementation PWRichMediaManagerTest

- (void)setUp {
    [super setUp];
    self.manager = [PWRichMediaManager sharedManager];
    self.manager.delegate = nil;

    self.mockConfiguration = OCMClassMock([PWModalWindowConfiguration class]);
    OCMStub([self.mockConfiguration shared]).andReturn(self.mockConfiguration);

    self.mockMessageViewController = OCMClassMock([PWMessageViewController class]);

    self.mockConfig = OCMClassMock([PWConfig class]);
    OCMStub([self.mockConfig config]).andReturn(self.mockConfig);

    self.mockRichMedia = OCMClassMock([PWRichMedia class]);
}

- (void)tearDown {
    self.manager.delegate = nil;
    [self.mockConfiguration stopMocking];
    [self.mockMessageViewController stopMocking];
    [self.mockConfig stopMocking];
    [self.mockRichMedia stopMocking];
    self.mockConfiguration = nil;
    self.mockMessageViewController = nil;
    self.mockConfig = nil;
    self.mockRichMedia = nil;
    self.manager = nil;
    [super tearDown];
}

#pragma mark - shouldPresentRichMedia:

/// Verifies that shouldPresentRichMedia: returns YES when no delegate is set.
- (void)testShouldPresentReturnsYesWhenDelegateIsNil {
    self.manager.delegate = nil;

    BOOL result = [self.manager shouldPresentRichMedia:self.mockRichMedia];

    XCTAssertTrue(result);
}

/// Verifies that shouldPresentRichMedia: returns YES when the delegate does not implement the optional method.
- (void)testShouldPresentReturnsYesWhenDelegateDoesNotImplementMethod {
    id partialDelegate = [NSObject new];
    self.manager.delegate = (id)partialDelegate;

    BOOL result = [self.manager shouldPresentRichMedia:self.mockRichMedia];

    XCTAssertTrue(result);
}

/// Verifies that shouldPresentRichMedia: forwards the delegate's YES answer.
- (void)testShouldPresentReturnsYesFromDelegate {
    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(YES);
    self.manager.delegate = mockDelegate;

    BOOL result = [self.manager shouldPresentRichMedia:self.mockRichMedia];

    XCTAssertTrue(result);
}

/// Verifies that shouldPresentRichMedia: forwards the delegate's NO answer.
- (void)testShouldPresentReturnsNoFromDelegate {
    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(NO);
    self.manager.delegate = mockDelegate;

    BOOL result = [self.manager shouldPresentRichMedia:self.mockRichMedia];

    XCTAssertFalse(result);
}

#pragma mark - presentRichMedia: (Modal style)

/// Regression for SDK-815: when delegate returns NO, modal presentation is skipped — no PWModalWindow is allocated.
- (void)testPresentRichMediaSkipsModalConfigurationWhenDelegateReturnsNo {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeModal);

    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(NO);
    self.manager.delegate = mockDelegate;

    OCMReject([self.mockConfiguration presentModalWindow:OCMOCK_ANY]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockConfiguration);
}

/// Verifies that modal presentation proceeds when the delegate returns YES.
- (void)testPresentRichMediaCallsModalConfigurationWhenDelegateReturnsYes {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeModal);

    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(YES);
    self.manager.delegate = mockDelegate;

    OCMExpect([self.mockConfiguration presentModalWindow:self.mockRichMedia]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockConfiguration);
}

/// Verifies that modal presentation proceeds when no delegate is set (default YES).
- (void)testPresentRichMediaCallsModalConfigurationWhenDelegateIsNil {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeModal);
    self.manager.delegate = nil;

    OCMExpect([self.mockConfiguration presentModalWindow:self.mockRichMedia]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockConfiguration);
}

#pragma mark - presentRichMedia: (Legacy / Default style)

/// Verifies that legacy presentation is skipped when the delegate returns NO.
- (void)testPresentRichMediaSkipsMessageViewControllerWhenDelegateReturnsNo {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeLegacy);

    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(NO);
    self.manager.delegate = mockDelegate;

    OCMReject([self.mockMessageViewController presentWithRichMedia:OCMOCK_ANY]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockMessageViewController);
}

/// Verifies that legacy presentation proceeds when the delegate returns YES.
- (void)testPresentRichMediaCallsMessageViewControllerForLegacyStyleWhenDelegateAllows {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeLegacy);

    id mockDelegate = OCMProtocolMock(@protocol(PWRichMediaPresentingDelegate));
    OCMStub([mockDelegate richMediaManager:OCMOCK_ANY shouldPresentRichMedia:OCMOCK_ANY]).andReturn(YES);
    self.manager.delegate = mockDelegate;

    OCMExpect([self.mockMessageViewController presentWithRichMedia:self.mockRichMedia]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockMessageViewController);
}

/// Verifies that default style routes to PWMessageViewController.
- (void)testPresentRichMediaCallsMessageViewControllerForDefaultStyle {
    OCMStub([(PWConfig *)self.mockConfig richMediaStyle]).andReturn(PWRichMediaStyleTypeDefault);
    self.manager.delegate = nil;

    OCMExpect([self.mockMessageViewController presentWithRichMedia:self.mockRichMedia]);

    [self.manager presentRichMedia:self.mockRichMedia];

    OCMVerifyAll(self.mockMessageViewController);
}

@end
