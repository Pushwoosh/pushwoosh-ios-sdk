
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWManagerBridge.h"
#import "PushwooshConfig.h"

@interface PWManagerBridge (Test)

@property (nonatomic, copy) NSDictionary *launchNotification;

@end

@interface PWLaunchNotificationTest : XCTestCase

@end

@implementation PWLaunchNotificationTest

- (void)tearDown {
    [PWManagerBridge shared].launchNotification = nil;
    [super tearDown];
}

/// Verifies that getLaunchNotification returns nil when no push launched the app.
- (void)testGetLaunchNotification_returnsNilByDefault {
    NSDictionary *result = [PushwooshConfig getLaunchNotification];

    XCTAssertNil(result);
}

/// Verifies that getLaunchNotification returns the payload set on PWManagerBridge.
- (void)testGetLaunchNotification_returnsPayloadWhenSet {
    NSDictionary *payload = @{@"aps": @{@"alert": @"Test push"}, @"p": @"custom_data"};
    [PWManagerBridge shared].launchNotification = payload;

    NSDictionary *result = [PushwooshConfig getLaunchNotification];

    XCTAssertEqualObjects(result, payload);
}

/// Verifies that getLaunchNotification persists across multiple reads.
- (void)testGetLaunchNotification_persistsAcrossMultipleReads {
    NSDictionary *payload = @{@"aps": @{@"alert": @"Test push"}};
    [PWManagerBridge shared].launchNotification = payload;

    XCTAssertEqualObjects([PushwooshConfig getLaunchNotification], payload);
    XCTAssertEqualObjects([PushwooshConfig getLaunchNotification], payload);
}

@end
