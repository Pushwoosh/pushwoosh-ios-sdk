#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWServerCommunicationManager.h"
#import "PWPreferences.h"

@interface PWServerCommunicationManagerTest : XCTestCase

@property (nonatomic, strong) id mockPreferencesInstance;
@property (nonatomic, assign) BOOL originalServerCommunicationEnabled;

@end

@implementation PWServerCommunicationManagerTest

- (void)setUp {
    self.originalServerCommunicationEnabled = [[PWPreferences preferences] isServerCommunicationEnabled];
    self.mockPreferencesInstance = OCMPartialMock([PWPreferences preferences]);
}

- (void)tearDown {
    [[PWPreferences preferences] setIsServerCommunicationEnabled:self.originalServerCommunicationEnabled];
    [self.mockPreferencesInstance stopMocking];
    self.mockPreferencesInstance = nil;
}

- (void)testSharedInstanceReturnsSameInstance {
    PWServerCommunicationManager *instance1 = [PWServerCommunicationManager sharedInstance];
    PWServerCommunicationManager *instance2 = [PWServerCommunicationManager sharedInstance];

    XCTAssertNotNil(instance1);
    XCTAssertNotNil(instance2);
    XCTAssertEqual(instance1, instance2);
}

- (void)testServerCommunicationAllowedWhenEnabled {
    OCMStub([self.mockPreferencesInstance isServerCommunicationEnabled]).andReturn(YES);

    PWServerCommunicationManager *manager = [PWServerCommunicationManager sharedInstance];
    BOOL allowed = manager.serverCommunicationAllowed;

    XCTAssertTrue(allowed);
}

- (void)testServerCommunicationAllowedWhenDisabled {
    OCMStub([self.mockPreferencesInstance isServerCommunicationEnabled]).andReturn(NO);

    PWServerCommunicationManager *manager = [PWServerCommunicationManager sharedInstance];
    BOOL allowed = manager.serverCommunicationAllowed;

    XCTAssertFalse(allowed);
}

- (void)testStartServerCommunicationWhenNotAllowed {
    OCMStub([self.mockPreferencesInstance isServerCommunicationEnabled]).andReturn(NO);

    XCTestExpectation *notificationExpectation = [self expectationForNotification:kPWServerCommunicationStarted object:nil handler:nil];

    PWServerCommunicationManager *manager = [PWServerCommunicationManager sharedInstance];
    [manager startServerCommunication];

    OCMVerify([self.mockPreferencesInstance setIsServerCommunicationEnabled:YES]);

    [self waitForExpectations:@[notificationExpectation] timeout:1.0];
}

- (void)testStartServerCommunicationWhenAlreadyAllowed {
    OCMStub([self.mockPreferencesInstance isServerCommunicationEnabled]).andReturn(YES);

    PWServerCommunicationManager *manager = [PWServerCommunicationManager sharedInstance];
    [manager startServerCommunication];

    OCMVerify(never(), [self.mockPreferencesInstance setIsServerCommunicationEnabled:YES]);
}

- (void)testStopServerCommunication {
    PWServerCommunicationManager *manager = [PWServerCommunicationManager sharedInstance];
    [manager stopServerCommunication];

    OCMVerify([self.mockPreferencesInstance setIsServerCommunicationEnabled:NO]);
}

- (void)testStartThenStopServerCommunication {
    OCMStub([self.mockPreferencesInstance isServerCommunicationEnabled]).andReturn(NO);

    PWServerCommunicationManager *manager = [PWServerCommunicationManager sharedInstance];
    [manager startServerCommunication];
    OCMVerify([self.mockPreferencesInstance setIsServerCommunicationEnabled:YES]);

    [manager stopServerCommunication];
    OCMVerify([self.mockPreferencesInstance setIsServerCommunicationEnabled:NO]);
}

- (void)testMultipleStartCalls {
    __block int callCount = 0;
    OCMStub([self.mockPreferencesInstance isServerCommunicationEnabled]).andDo(^(NSInvocation *invocation) {
        callCount++;
        BOOL returnValue = (callCount == 1) ? NO : YES;
        [invocation setReturnValue:&returnValue];
    });

    PWServerCommunicationManager *manager = [PWServerCommunicationManager sharedInstance];
    [manager startServerCommunication];
    [manager startServerCommunication];

    OCMVerify(times(1), [self.mockPreferencesInstance setIsServerCommunicationEnabled:YES]);
}

- (void)testMultipleStopCalls {
    PWServerCommunicationManager *manager = [PWServerCommunicationManager sharedInstance];
    [manager stopServerCommunication];
    [manager stopServerCommunication];

    OCMVerify(times(2), [self.mockPreferencesInstance setIsServerCommunicationEnabled:NO]);
}

- (void)testServerCommunicationStartedNotificationPosted {
    OCMStub([self.mockPreferencesInstance isServerCommunicationEnabled]).andReturn(NO);

    __block BOOL notificationReceived = NO;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kPWServerCommunicationStarted
                                                                    object:nil
                                                                     queue:[NSOperationQueue mainQueue]
                                                                usingBlock:^(NSNotification *note) {
        notificationReceived = YES;
    }];

    PWServerCommunicationManager *manager = [PWServerCommunicationManager sharedInstance];
    [manager startServerCommunication];

    XCTAssertTrue(notificationReceived);

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

- (void)testServerCommunicationStartedNotificationNotPostedWhenAlreadyAllowed {
    OCMStub([self.mockPreferencesInstance isServerCommunicationEnabled]).andReturn(YES);

    __block BOOL notificationReceived = NO;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:kPWServerCommunicationStarted
                                                                    object:nil
                                                                     queue:[NSOperationQueue mainQueue]
                                                                usingBlock:^(NSNotification *note) {
        notificationReceived = YES;
    }];

    PWServerCommunicationManager *manager = [PWServerCommunicationManager sharedInstance];
    [manager startServerCommunication];

    XCTAssertFalse(notificationReceived);

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

- (void)testConstantExists {
    XCTAssertNotNil(kPWServerCommunicationStarted);
    XCTAssertEqualObjects(kPWServerCommunicationStarted, @"kPWServerCommunicationStarted");
}

@end
