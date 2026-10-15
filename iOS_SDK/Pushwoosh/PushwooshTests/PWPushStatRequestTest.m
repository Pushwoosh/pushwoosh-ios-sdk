//
//  PWPushStatRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import <OCHamcrest/OCHamcrest.h>

#import "PWPushStatRequest.h"
#import "PWActionButton.h"

@interface PWPushStatRequestTest : XCTestCase

@property (nonatomic) PWPushStatRequest *request;

@end

@implementation PWPushStatRequestTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.request = [[PWPushStatRequest alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testMethodNameIsCorrect {
    NSString *methodName = [self.request methodName];

    XCTAssertEqualObjects(methodName, @"pushStat");
}

- (void)testRequestDictionaryHasParameters {
    [self.request setPushDict:@{@"md": @"md"}];
    NSDictionary *parameters = [self.request requestDictionary];

    assertThat(parameters, hasKey(@"metaData"));
}

#pragma mark - Action buttons

- (NSDictionary *)pushWithButtonsTappedAs:(NSString *)actionIdentifier {
    return @{ @"p" : @"hash",
              @"pw_msg" : @"1",
              @"pw_buttons" : @"[{\"id\":\"open_app\",\"label\":\"Open\",\"action\":\"open\"},"
                               "{\"id\":\"cancel_order\",\"label\":\"Cancel\",\"action\":\"custom\"}]",
              @"actionIdentifier" : actionIdentifier };
}

/// Verifies the open of a push sent by a button tap names that button, alongside the push's own hash.
- (void)testTappedButtonIsNamedInTheRequest {
    [self.request setPushDict:[self pushWithButtonsTappedAs:@"cancel_order"]];

    NSDictionary *parameters = [self.request requestDictionary];

    XCTAssertEqualObjects(parameters[@"button_id"], @"cancel_order");
    XCTAssertEqualObjects(parameters[@"hash"], @"hash");
}

/// Verifies a tap on the notification itself names no button, so an ordinary open is still an
/// ordinary open.
- (void)testPlainTapNamesNoButton {
    NSMutableDictionary *push = [[self pushWithButtonsTappedAs:@"x"] mutableCopy];
    [push removeObjectForKey:@"actionIdentifier"];
    [self.request setPushDict:push];

    NSDictionary *parameters = [self.request requestDictionary];

    XCTAssertNil(parameters[@"button_id"]);
    XCTAssertEqualObjects(parameters[@"hash"], @"hash");
}

/// Verifies a button of an old Control Panel category names no button: that path has no pw_buttons and
/// its statistics must not change shape.
- (void)testLegacyCategoryButtonNamesNoButton {
    [self.request setPushDict:@{ @"p" : @"hash", @"pw_msg" : @"1", @"actionIdentifier" : @"legacy_button" }];

    NSDictionary *parameters = [self.request requestDictionary];

    XCTAssertNil(parameters[@"button_id"]);
}

/// Verifies an action identifier this push does not carry names no button, so a stale response cannot
/// invent a click.
- (void)testUnknownActionIdentifierNamesNoButton {
    [self.request setPushDict:[self pushWithButtonsTappedAs:@"not_in_this_push"]];

    XCTAssertNil([self.request requestDictionary][@"button_id"]);
}

@end
