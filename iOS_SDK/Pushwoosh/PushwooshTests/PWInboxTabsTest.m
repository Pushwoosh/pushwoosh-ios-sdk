//  PWInboxTabsTest.m
//  Created by André Kis

#import <XCTest/XCTest.h>

#import "PWInboxTabs.h"
#import "PWInboxTabsFactory.h"
#import "PWInboxAllMessagesRequest.h"

@interface PWInboxTabsTest : XCTestCase
@end

@implementation PWInboxTabsTest

/// Verifies that a contract-shaped payload yields the all-title and the tabs in array order.
- (void)testParsesContractPayload {
    PWInboxTabs *tabs = [PWInboxTabsFactory tabsFromPayload:@{
        @"all_title": @"All",
        @"tabs": @[@{@"id": @"a1b2c3", @"title": @"Bills"},
                   @{@"id": @"d4e5f6", @"title": @"Promos"}]}];
    XCTAssertEqualObjects(tabs.allTitle, @"All");
    XCTAssertEqual(tabs.tabs.count, 2);
    XCTAssertEqualObjects(tabs.tabs[0].identifier, @"a1b2c3");
    XCTAssertEqualObjects(tabs.tabs[0].title, @"Bills");
    XCTAssertEqualObjects(tabs.tabs[1].identifier, @"d4e5f6");
}

/// Verifies that an absent payload, an empty tabs array and a blank all_title all mean "no tabs".
- (void)testNoTabsCases {
    XCTAssertNil([PWInboxTabsFactory tabsFromPayload:nil]);
    XCTAssertNil(([PWInboxTabsFactory tabsFromPayload:@{@"all_title": @"All", @"tabs": @[]}]));
    XCTAssertNil(([PWInboxTabsFactory tabsFromPayload:@{@"all_title": @"", @"tabs": @[@{@"id": @"a", @"title": @"A"}]}]));
    XCTAssertNil(([PWInboxTabsFactory tabsFromPayload:@{@"tabs": @[@{@"id": @"a", @"title": @"A"}]}]));
}

/// Verifies that a non-dictionary payload yields nil instead of raising.
- (void)testNonDictionaryPayload {
    XCTAssertNil([PWInboxTabsFactory tabsFromPayload:@"inbox_tabs"]);
    XCTAssertNil(([PWInboxTabsFactory tabsFromPayload:@[@"a", @"b"]]));
    XCTAssertNil([PWInboxTabsFactory tabsFromPayload:@42]);
}

/// Verifies that malformed entries and repeated ids are skipped while valid neighbours survive.
- (void)testSkipsMalformedEntriesAndDuplicateIds {
    PWInboxTabs *tabs = [PWInboxTabsFactory tabsFromPayload:@{
        @"all_title": @"All",
        @"tabs": @[@{@"id": @"a", @"title": @"A"},
                   @{@"id": @"", @"title": @"Blank"},
                   @{@"id": @"b"},
                   @{@"title": @"No id"},
                   @{@"id": @123, @"title": @"Numeric"},
                   @{@"id": @"a", @"title": @"Duplicate"},
                   @{@"id": @"c", @"title": @"C"}]}];
    XCTAssertEqual(tabs.tabs.count, 2);
    XCTAssertEqualObjects(tabs.tabs[0].identifier, @"a");
    XCTAssertEqualObjects(tabs.tabs[0].title, @"A");
    XCTAssertEqualObjects(tabs.tabs[1].identifier, @"c");
}

/// Verifies that non-dictionary elements inside tabs are skipped, not fatal.
- (void)testSkipsNonDictionaryTabElements {
    PWInboxTabs *tabs = [PWInboxTabsFactory tabsFromPayload:@{
        @"all_title": @"All",
        @"tabs": @[@"a1b2c3", @42, [NSNull null], @{@"id": @"c", @"title": @"C"}]}];
    XCTAssertEqual(tabs.tabs.count, 1);
    XCTAssertEqualObjects(tabs.tabs[0].identifier, @"c");
}

/// Verifies that every malformed entry being dropped collapses to "no tabs".
- (void)testAllEntriesDroppedYieldsNil {
    XCTAssertNil(([PWInboxTabsFactory tabsFromPayload:@{@"all_title": @"All", @"tabs": @[@{@"id": @""}]}]));
}

/// Verifies that tab lists compare by every field and by tab order.
- (void)testEquality {
    PWInboxTabs *(^make)(NSString *, NSArray *) = ^(NSString *allTitle, NSArray *pairs) {
        NSMutableArray *list = [NSMutableArray new];
        for (NSArray *pair in pairs) {
            [list addObject:[[PWInboxTab alloc] initWithIdentifier:pair[0] title:pair[1]]];
        }
        return [[PWInboxTabs alloc] initWithAllTitle:allTitle tabs:list];
    };
    PWInboxTabs *base = make(@"All", @[@[@"a", @"A"], @[@"b", @"B"]]);
    XCTAssertEqualObjects(base, make(@"All", @[@[@"a", @"A"], @[@"b", @"B"]]));
    XCTAssertEqual(base.hash, make(@"All", @[@[@"a", @"A"], @[@"b", @"B"]]).hash);
    XCTAssertNotEqualObjects(base, make(@"Alle", @[@[@"a", @"A"], @[@"b", @"B"]]));
    XCTAssertNotEqualObjects(base, make(@"All", @[@[@"b", @"B"], @[@"a", @"A"]]));
    XCTAssertNotEqualObjects(base, make(@"All", @[@[@"a", @"Invoices"], @[@"b", @"B"]]));
    XCTAssertEqualObjects([[PWInboxTab alloc] initWithIdentifier:@"a" title:@"A"],
                          [[PWInboxTab alloc] initWithIdentifier:@"a" title:@"A"]);
}

/// Verifies that a tab list survives a secure-coding round trip.
- (void)testSecureCodingRoundTrip {
    PWInboxTabs *tabs = [[PWInboxTabs alloc] initWithAllTitle:@"All"
                                                           tabs:@[[[PWInboxTab alloc] initWithIdentifier:@"a" title:@"A"],
                                                                  [[PWInboxTab alloc] initWithIdentifier:@"b" title:@"B"]]];
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:tabs requiringSecureCoding:YES error:&error];
    XCTAssertNil(error);
    XCTAssertNotNil(data);

    NSError *decodeError = nil;
    PWInboxTabs *decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[PWInboxTabs class] fromData:data error:&decodeError];
    XCTAssertNil(decodeError);
    XCTAssertEqualObjects(tabs, decoded);
}

/// Verifies that an archive missing the encoded keys decodes to nil instead of an object with nil fields.
- (void)testIncompleteArchiveDecodesToNil {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:@{} requiringSecureCoding:YES error:nil];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
    unarchiver.decodingFailurePolicy = NSDecodingFailurePolicySetErrorAndReturn;

    XCTAssertNil([[PWInboxTab alloc] initWithCoder:unarchiver]);
    XCTAssertNil([[PWInboxTabs alloc] initWithCoder:unarchiver]);
}

/// Verifies that the raw inbox_tabs dictionary is carried off the response alongside the messages.
- (void)testParseResponseCarriesTabsPayload {
    PWInboxAllMessagesRequest *request = [[PWInboxAllMessagesRequest alloc] initWithLastRequestTime:nil];
    [request parseResponse:@{@"messages": @[@{@"inbox_id": @"c1", @"order": @1, @"rt": @2000000000,
                                             @"text": @"t", @"action_type": @1, @"status": @1}],
                             @"inbox_tabs": @{@"all_title": @"All",
                                              @"tabs": @[@{@"id": @"a1b2c3", @"title": @"Bills"}]}}];
    XCTAssertEqualObjects(request.tabsPayload[@"all_title"], @"All");
    XCTAssertEqual(request.messages.count, 1);
}

/// Verifies that a non-dictionary inbox_tabs yields no payload and still loads the messages.
- (void)testParseResponseWithBrokenTabsStillLoadsMessages {
    PWInboxAllMessagesRequest *request = [[PWInboxAllMessagesRequest alloc] initWithLastRequestTime:nil];
    [request parseResponse:@{@"messages": @[@{@"inbox_id": @"c1", @"order": @1, @"rt": @2000000000,
                                             @"text": @"t", @"action_type": @1, @"status": @1}],
                             @"inbox_tabs": @"not a dictionary"}];
    XCTAssertNil(request.tabsPayload);
    XCTAssertEqual(request.messages.count, 1);
}

/// Verifies that a response with no inbox_tabs key yields no payload.
- (void)testParseResponseWithoutTabsKey {
    PWInboxAllMessagesRequest *request = [[PWInboxAllMessagesRequest alloc] initWithLastRequestTime:nil];
    [request parseResponse:@{@"messages": @[@{@"inbox_id": @"c1", @"order": @1, @"rt": @2000000000,
                                             @"text": @"t", @"action_type": @1, @"status": @1}]}];
    XCTAssertNil(request.tabsPayload);
    XCTAssertEqual(request.messages.count, 1);
}

@end
