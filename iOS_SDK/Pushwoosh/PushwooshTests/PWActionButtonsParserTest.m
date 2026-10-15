//
//  PWActionButtonsParserTest.m
//  PushwooshTests
//
//  Created by André Kis on 08.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <UserNotifications/UserNotifications.h>

#import "PWActionButton.h"
#import "PWActionButtonsParser.h"

static NSDictionary *PWPushWithButtonsJSON(NSString *json) {
    return @{ @"aps" : @{ @"alert" : @"hi" }, @"p" : @"hash", @"pw_msg" : @"1", @"pw_buttons" : json };
}

@interface PWActionButtonsParserTest : XCTestCase
@end

@implementation PWActionButtonsParserTest

- (NSArray<PWActionButton *> *)parse:(NSString *)json {
    return [PWActionButtonsParser buttonsFromUserInfo:PWPushWithButtonsJSON(json)];
}

- (NSArray<NSString *> *)identifiers:(NSArray<PWActionButton *> *)buttons {
    NSMutableArray *ids = [NSMutableArray array];
    for (PWActionButton *button in buttons) {
        [ids addObject:button.identifier];
    }
    return ids;
}

#pragma mark - The contract as the spec writes it

/// Verifies the example payload of the contract parses into three buttons with the labels, actions,
/// urls and style it names, in payload order.
- (void)testValidPayloadParsesEveryField {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"open_order\",\"label\":\"Open order\",\"action\":\"deeplink\",\"url\":\"myapp://orders/4521\"},"
                                                     "{\"id\":\"site\",\"label\":\"Website\",\"action\":\"url\",\"url\":\"https://shop.com/4521\"},"
                                                     "{\"id\":\"cancel_order\",\"label\":\"Cancel\",\"action\":\"custom\",\"style\":\"destructive\"}]"];

    XCTAssertEqual(buttons.count, 3);

    XCTAssertEqualObjects(buttons[0].identifier, @"open_order");
    XCTAssertEqualObjects(buttons[0].label, @"Open order");
    XCTAssertEqual(buttons[0].action, PWActionButtonActionDeeplink);
    XCTAssertEqualObjects(buttons[0].url, @"myapp://orders/4521");
    XCTAssertFalse(buttons[0].destructive);
    XCTAssertTrue(buttons[0].opensApplication);

    XCTAssertEqual(buttons[1].action, PWActionButtonActionUrl);
    XCTAssertEqualObjects(buttons[1].url, @"https://shop.com/4521");
    XCTAssertTrue(buttons[1].opensApplication);

    XCTAssertEqual(buttons[2].action, PWActionButtonActionCustom);
    XCTAssertNil(buttons[2].url);
    XCTAssertTrue(buttons[2].destructive);
    XCTAssertFalse(buttons[2].opensApplication);
}

/// Verifies an `open` button opens the application and carries no url of its own.
- (void)testOpenActionOpensApplicationWithoutUrl {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\",\"url\":\"https://ignored\"}]"];

    XCTAssertEqual(buttons.count, 1);
    XCTAssertEqual(buttons[0].action, PWActionButtonActionOpen);
    XCTAssertTrue(buttons[0].opensApplication);
    XCTAssertNil(buttons[0].url);
}

#pragma mark - A broken payload costs the push nothing but its buttons

/// Verifies a push without pw_buttons has no buttons.
- (void)testPushWithoutButtonsHasNone {
    NSDictionary *push = @{ @"aps" : @{ @"alert" : @"hi" }, @"p" : @"hash", @"pw_msg" : @"1" };

    XCTAssertEqual([PWActionButtonsParser buttonsFromUserInfo:push].count, 0);
}

/// Verifies a nil payload is answered with no buttons rather than a crash.
- (void)testNilUserInfoHasNoButtons {
    XCTAssertEqual([PWActionButtonsParser buttonsFromUserInfo:nil].count, 0);
}

/// Verifies malformed JSON costs the push its buttons and nothing else.
- (void)testBrokenJsonHasNoButtons {
    XCTAssertEqual([self parse:@"[{\"id\":\"a\",\"label\""].count, 0);
}

/// Verifies a JSON value that is not an array (an object, a bare string) has no buttons.
- (void)testNonArrayJsonHasNoButtons {
    XCTAssertEqual([self parse:@"{\"id\":\"a\"}"].count, 0);
    XCTAssertEqual([self parse:@"\"nope\""].count, 0);
}

/// Verifies a pw_buttons value of the wrong type altogether is answered with no buttons.
- (void)testNonStringPayloadValueHasNoButtons {
    NSDictionary *push = @{ @"aps" : @{ @"alert" : @"hi" }, @"pw_msg" : @"1", @"pw_buttons" : @42 };

    XCTAssertEqual([PWActionButtonsParser buttonsFromUserInfo:push].count, 0);
}

/// Verifies a pw_buttons value sent as a native array instead of a JSON string carries no buttons.
- (void)testPayloadSentAsArrayHasNoButtons {
    NSDictionary *push = @{ @"aps" : @{ @"alert" : @"hi" },
                            @"pw_msg" : @"1",
                            @"pw_buttons" : @[ @{ @"id" : @"a", @"label" : @"A", @"action" : @"open" } ] };

    XCTAssertEqual([PWActionButtonsParser buttonsFromUserInfo:push].count, 0);
}

#pragma mark - One bad button costs only itself

/// Verifies a button missing id, label or action is skipped while its neighbours survive.
- (void)testButtonMissingRequiredFieldIsSkipped {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\"},"
                                                     "{\"label\":\"NoId\",\"action\":\"open\"},"
                                                     "{\"id\":\"c\",\"action\":\"open\"},"
                                                     "{\"id\":\"d\",\"label\":\"D\"},"
                                                     "{\"id\":\"e\",\"label\":\"E\",\"action\":\"open\"}]"];

    XCTAssertEqualObjects([self identifiers:buttons], (@[ @"a", @"e" ]));
}

/// Verifies url and deeplink buttons without a url are skipped while their neighbours survive.
- (void)testUrlActionWithoutUrlIsSkipped {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"url\"},"
                                                     "{\"id\":\"b\",\"label\":\"B\",\"action\":\"deeplink\"},"
                                                     "{\"id\":\"c\",\"label\":\"C\",\"action\":\"open\"}]"];

    XCTAssertEqualObjects([self identifiers:buttons], (@[ @"c" ]));
}

/// Verifies an action nobody knows is skipped rather than guessed at.
- (void)testUnknownActionIsSkipped {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"teleport\"},"
                                                     "{\"id\":\"b\",\"label\":\"B\",\"action\":\"open\"}]"];

    XCTAssertEqualObjects([self identifiers:buttons], (@[ @"b" ]));
}

/// Verifies a repeated id keeps the first button and drops the later one, so the tap stays unambiguous.
- (void)testRepeatedIdKeepsTheFirstButton {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"a\",\"label\":\"First\",\"action\":\"open\"},"
                                                     "{\"id\":\"a\",\"label\":\"Second\",\"action\":\"custom\"},"
                                                     "{\"id\":\"b\",\"label\":\"B\",\"action\":\"open\"}]"];

    XCTAssertEqualObjects([self identifiers:buttons], (@[ @"a", @"b" ]));
    XCTAssertEqualObjects(buttons[0].label, @"First");
}

/// Verifies only the first three valid buttons are kept, since iOS shows no more.
- (void)testMoreThanThreeButtonsKeepsTheFirstThree {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\"},"
                                                     "{\"id\":\"b\",\"label\":\"B\",\"action\":\"open\"},"
                                                     "{\"id\":\"c\",\"label\":\"C\",\"action\":\"open\"},"
                                                     "{\"id\":\"d\",\"label\":\"D\",\"action\":\"open\"},"
                                                     "{\"id\":\"e\",\"label\":\"E\",\"action\":\"open\"}]"];

    XCTAssertEqualObjects([self identifiers:buttons], (@[ @"a", @"b", @"c" ]));
}

/// Verifies the limit counts valid buttons: three valid ones behind two broken ones still show up.
- (void)testLimitCountsValidButtonsOnly {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"bad1\",\"action\":\"open\"},"
                                                     "{\"id\":\"bad2\",\"label\":\"B\",\"action\":\"nope\"},"
                                                     "{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\"},"
                                                     "{\"id\":\"b\",\"label\":\"B\",\"action\":\"open\"},"
                                                     "{\"id\":\"c\",\"label\":\"C\",\"action\":\"open\"},"
                                                     "{\"id\":\"d\",\"label\":\"D\",\"action\":\"open\"}]"];

    XCTAssertEqualObjects([self identifiers:buttons], (@[ @"a", @"b", @"c" ]));
}

/// Verifies fields nobody asked for are ignored and the button still parses.
- (void)testUnknownFieldsAreIgnored {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\",\"icon\":\"star\",\"weight\":7}]"];

    XCTAssertEqualObjects([self identifiers:buttons], (@[ @"a" ]));
}

/// Verifies an unknown style is the default style rather than a reason to drop the button.
- (void)testUnknownStyleIsNotDestructive {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\",\"style\":\"neon\"}]"];

    XCTAssertEqual(buttons.count, 1);
    XCTAssertFalse(buttons[0].destructive);
}

#pragma mark - Payloads that would crash or hijack

/// Verifies array entries that are not objects are skipped instead of being messaged as dictionaries.
- (void)testNonDictionaryEntriesAreSkipped {
    NSArray<PWActionButton *> *buttons = [self parse:@"[\"x\", 3, null, [1,2], {\"id\":\"a\",\"label\":\"A\",\"action\":\"open\"}]"];

    XCTAssertEqualObjects([self identifiers:buttons], (@[ @"a" ]));
}

/// Verifies fields of the wrong JSON type cost their own button and nothing else.
- (void)testNonStringFieldValuesAreSkipped {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":7,\"label\":\"A\",\"action\":\"open\"},"
                                                     "{\"id\":\"b\",\"label\":{\"x\":1},\"action\":\"open\"},"
                                                     "{\"id\":\"c\",\"label\":\"C\",\"action\":\"url\",\"url\":9},"
                                                     "{\"id\":\"d\",\"label\":null,\"action\":\"open\"},"
                                                     "{\"id\":\"e\",\"label\":\"E\",\"action\":\"open\"}]"];

    XCTAssertEqualObjects([self identifiers:buttons], (@[ @"e" ]));
}

/// Verifies an empty id is rejected: it would match nothing on tap and can only confuse the lookup.
- (void)testEmptyIdIsSkipped {
    NSArray<PWActionButton *> *buttons = [self parse:@"[{\"id\":\"\",\"label\":\"A\",\"action\":\"open\"},"
                                                     "{\"id\":\"b\",\"label\":\"B\",\"action\":\"open\"}]"];

    XCTAssertEqualObjects([self identifiers:buttons], (@[ @"b" ]));
}

/// Verifies a button cannot claim the identifiers iOS uses for a plain tap and for a dismissal: such a
/// button would swallow the push's own link on every tap on the notification body.
- (void)testSystemActionIdentifiersAreRejected {
    NSString *json = [NSString stringWithFormat:@"[{\"id\":\"%@\",\"label\":\"A\",\"action\":\"open\"},"
                                                 "{\"id\":\"%@\",\"label\":\"B\",\"action\":\"open\"},"
                                                 "{\"id\":\"c\",\"label\":\"C\",\"action\":\"open\"}]",
                      UNNotificationDefaultActionIdentifier, UNNotificationDismissActionIdentifier];

    XCTAssertEqualObjects([self identifiers:[self parse:json]], (@[ @"c" ]));
}

#pragma mark - Looking a tapped action up

/// Verifies a tapped action identifier resolves to the button of this push that carries it.
- (void)testButtonForActionIdentifierFindsTheButton {
    NSDictionary *push = PWPushWithButtonsJSON(@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\"},"
                                                "{\"id\":\"b\",\"label\":\"B\",\"action\":\"custom\"}]");

    PWActionButton *button = [PWActionButtonsParser buttonForActionIdentifier:@"b" inUserInfo:push];

    XCTAssertEqualObjects(button.identifier, @"b");
    XCTAssertEqual(button.action, PWActionButtonActionCustom);
}

/// Verifies an action identifier this push does not carry resolves to nothing, so an old-style category
/// button and a plain tap keep the behaviour they had.
- (void)testButtonForUnknownActionIdentifierIsNil {
    NSDictionary *push = PWPushWithButtonsJSON(@"[{\"id\":\"a\",\"label\":\"A\",\"action\":\"open\"}]");

    XCTAssertNil([PWActionButtonsParser buttonForActionIdentifier:@"legacy_button" inUserInfo:push]);
    XCTAssertNil([PWActionButtonsParser buttonForActionIdentifier:UNNotificationDefaultActionIdentifier inUserInfo:push]);
    XCTAssertNil([PWActionButtonsParser buttonForActionIdentifier:nil inUserInfo:push]);
}

/// Verifies a push with no pw_buttons resolves no action identifier at all.
- (void)testButtonForActionIdentifierOnPushWithoutButtonsIsNil {
    NSDictionary *push = @{ @"aps" : @{ @"alert" : @"hi" }, @"pw_msg" : @"1" };

    XCTAssertNil([PWActionButtonsParser buttonForActionIdentifier:@"a" inUserInfo:push]);
}

@end
