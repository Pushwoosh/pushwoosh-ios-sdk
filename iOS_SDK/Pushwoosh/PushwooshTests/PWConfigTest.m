//
//  PWConfig.m
//  PushwooshTests
//
//  Created by Fectum on 20/09/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PWConfig.h"
#import "PWBundleMock.h"

@interface PWConfigTest : XCTestCase

@property (nonatomic) PWConfig *config;

@end

@implementation PWConfigTest

- (void)setUp {
    [super setUp];
    
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSendPushStatIfAlertsDisabledNo {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.sendPushStatIfAlertsDisabled = NO;

    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    BOOL result = _config.sendPushStatIfAlertsDisabled;
    XCTAssertEqual(NO, result);
}

- (void)testSendPushStatIfAlertsDisabledYes {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.sendPushStatIfAlertsDisabled = YES;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    BOOL result = _config.sendPushStatIfAlertsDisabled;
    XCTAssertEqual(YES, result);
}

- (void)testSendPurchaseTrackingEnabled {
    PWBundleMock *bundleMock = (id)[PWBundleMock new];
    bundleMock.sendPurchaseTrackingEnabled = YES;
    _config = [[PWConfig alloc] initWithBundle:bundleMock];
    BOOL result = _config.sendPurchaseTrackingEnabled;
    XCTAssertEqual(YES, result);
}

@end
