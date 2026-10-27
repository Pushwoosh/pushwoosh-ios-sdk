//  PWInboxTabsIntegrationTest.m
//  Created by André Kis

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWInbox.h"
#import "PushwooshFramework.h"
#import "Pushwoosh+Internal.h"
#import "PWInboxStorage.h"
#import "PWInboxService.h"
#import "PWInboxMessageInternal.h"
#import "PWRequest.h"
#import "PWRequestManager.h"

@interface PWInboxService (Test)

@property (nonatomic) PWRequestManager *requestManager;

@end

@interface PWInbox (Test)

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) PWInboxStorage *storage;
@property (nonatomic, readonly) PWInboxService *service;

@end

@interface PWInboxTabsIntegrationTest : XCTestCase

@end

@implementation PWInboxTabsIntegrationTest

+ (void)removeStorageFiles {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths.firstObject;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"PWInbox.serviceMessages"] error:nil];
    [fm removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"PWInbox.pushNotificationMessages"] error:nil];
    [fm removeItemAtPath:[documentsDirectory stringByAppendingPathComponent:@"PWInbox.tabs"] error:nil];
}

- (void)setUp {
    [super setUp];
    [self.class removeStorageFiles];
    [[PWInbox sharedInstance].storage reset];
    [[PWInbox sharedInstance].service reset];
}

- (void)tearDown {
    [[PWInbox sharedInstance].storage reset];
    [[PWInbox sharedInstance].service reset];
    [self.class removeStorageFiles];
    [super tearDown];
}

#pragma mark - Helpers

- (NSDictionary *)messageDictWithCode:(NSString *)code tab:(nullable NSString *)tab {
    NSDictionary *actionParams = tab ? @{@"pw_inbox_tab": tab} : @{};
    NSData *data = [NSJSONSerialization dataWithJSONObject:actionParams options:0 error:nil];
    NSString *actionParamsString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return @{
        @"inbox_id": code,
        @"order": @1,
        @"rt": @2000000000,
        @"send_date": @1700000000,
        @"text": @"text",
        @"title": @"title",
        @"action_type": @0,
        @"status": @(PWInboxMessageStatusDelivered),
        @"action_params": actionParamsString,
    };
}

/// Resets the inbox service rate limiter and stubs its next request with a contract-shaped response,
/// as OCMClassMock([PWRequestManager class]) in PWInboxServiceTest.m does.
- (void)respondWithTabs:(nullable NSDictionary *)tabsPayload messages:(NSArray *)messageDicts error:(nullable NSError *)error {
    [[PWInbox sharedInstance].service reset];
    // A stale currentUserID from a sibling suite would reinstall the real request manager.
    [[PWInbox sharedInstance].service canReloadData];
    [[PWInbox sharedInstance].service reset];

    id requestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([requestManager sendRequest:[OCMArg checkWithBlock:^BOOL(id request) {
        NSMutableDictionary *response = [NSMutableDictionary new];
        response[@"messages"] = messageDicts ?: @[];
        if (tabsPayload) {
            response[@"inbox_tabs"] = tabsPayload;
        }
        [request parseResponse:response];
        return YES;
    }] completion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
        void (^completion)(NSError *);
        [invocation getArgument:&completion atIndex:3];
        if (completion) {
            completion(error);
        }
    });

    [PWInbox sharedInstance].service.requestManager = requestManager;
}

- (void)loadMessagesAndWait {
    XCTestExpectation *expectation = [self expectationWithDescription:@"loadMessages"];
    [[Pushwoosh inbox] loadMessagesWithCompletion:^(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error) {
        [expectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:2 handler:nil];
}

#pragma mark - Tests

/// Verifies that a contract response makes getTabs report the all-title and the tabs in server order.
- (void)testSuccessfulResponsePublishesTabs {
    [self respondWithTabs:@{@"all_title": @"All",
                            @"tabs": @[@{@"id": @"a1b2c3", @"title": @"Bills"},
                                       @{@"id": @"d4e5f6", @"title": @"Promos"}]}
                 messages:@[[self messageDictWithCode:@"c1" tab:@"a1b2c3"]]
                    error:nil];

    [self loadMessagesAndWait];

    XCTAssertEqualObjects([[Pushwoosh inbox] getTabs].allTitle, @"All");
    XCTAssertEqualObjects([[Pushwoosh inbox] getTabs].tabs[0].identifier, @"a1b2c3");
    XCTAssertEqualObjects([[Pushwoosh inbox] getTabs].tabs[1].identifier, @"d4e5f6");
}

/// Verifies that the next successful response replaces the whole list and that a response without the field clears it.
- (void)testNextResponseReplacesAndEmptyResponseClears {
    [self respondWithTabs:@{@"all_title": @"A", @"tabs": @[@{@"id": @"a", @"title": @"A"}]}
                 messages:@[]
                    error:nil];
    [self loadMessagesAndWait];
    XCTAssertEqualObjects([[Pushwoosh inbox] getTabs].tabs[0].identifier, @"a");

    [self respondWithTabs:@{@"all_title": @"B", @"tabs": @[@{@"id": @"b", @"title": @"B"}]}
                 messages:@[]
                    error:nil];
    [self loadMessagesAndWait];
    XCTAssertEqual([[Pushwoosh inbox] getTabs].tabs.count, 1u);
    XCTAssertEqualObjects([[Pushwoosh inbox] getTabs].tabs[0].identifier, @"b");

    [self respondWithTabs:nil messages:@[] error:nil];
    [self loadMessagesAndWait];
    XCTAssertNil([[Pushwoosh inbox] getTabs]);
}

/// Verifies that a network error leaves the previously published list untouched.
- (void)testNetworkErrorKeepsPreviousTabs {
    [self respondWithTabs:@{@"all_title": @"A", @"tabs": @[@{@"id": @"a", @"title": @"A"}]}
                 messages:@[]
                    error:nil];
    [self loadMessagesAndWait];
    XCTAssertNotNil([[Pushwoosh inbox] getTabs]);

    [self respondWithTabs:nil messages:@[] error:[NSError errorWithDomain:@"test" code:1 userInfo:nil]];
    [self loadMessagesAndWait];

    XCTAssertEqualObjects([[Pushwoosh inbox] getTabs].tabs[0].identifier, @"a");
}

/// Verifies that a broken inbox_tabs yields no tabs while the response's messages still load.
- (void)testBrokenTabsStillDeliversMessages {
    [self respondWithTabs:(NSDictionary *)@"oops"
                 messages:@[[self messageDictWithCode:@"c1" tab:nil]]
                    error:nil];

    [self loadMessagesAndWait];

    XCTAssertNil([[Pushwoosh inbox] getTabs]);
    XCTAssertNotNil([[Pushwoosh inbox] messageForCode:@"c1"]);
}

/// Verifies that the tab list is already fresh by the time the inbox update notification fires.
- (void)testTabsAreFreshWhenUpdateNotificationArrives {
    [self respondWithTabs:@{@"all_title": @"A", @"tabs": @[@{@"id": @"a", @"title": @"A"}]}
                 messages:@[[self messageDictWithCode:@"c1" tab:nil]]
                    error:nil];

    __block BOOL observerSawTabs = NO;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:PWInboxMessagesDidUpdateNotification
                                                                      object:nil
                                                                       queue:nil
                                                                  usingBlock:^(NSNotification * _Nonnull note) {
        observerSawTabs = [[Pushwoosh inbox] getTabs] != nil;
    }];

    [self loadMessagesAndWait];

    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    XCTAssertTrue(observerSawTabs);
}

/// Verifies that a message delivered by push reports the tab id from the payload root.
- (void)testPushDeliveredMessageCarriesTabId {
    [PWInbox addInboxMessageFromPushNotification:@{@"pw_inbox": @"c9",
                                                    @"inbox_params": @{@"rt": @"2033-01-01"},
                                                    @"aps": @{@"alert": @"hi"},
                                                    @"pw_inbox_tab": @"a1b2c3"}];

    id<PWInboxMessageProtocol> message = [[Pushwoosh inbox] messageForCode:@"c9"];

    XCTAssertNotNil(message);
    XCTAssertEqualObjects(message.tabId, @"a1b2c3");
}

/// Verifies that a fresh storage over the same files serves the last list (restart) and that reset clears it (app code change).
- (void)testRestartKeepsTabsAndApplicationResetClearsThem {
    [self respondWithTabs:@{@"all_title": @"A", @"tabs": @[@{@"id": @"a", @"title": @"A"}]}
                 messages:@[]
                    error:nil];
    [self loadMessagesAndWait];
    XCTAssertNotNil([[Pushwoosh inbox] getTabs]);

    PWInboxStorage *restarted = [PWInboxStorage new];
    XCTAssertEqualObjects(restarted.tabs, [[Pushwoosh inbox] getTabs]);

    [PWInbox resetApplication];
    XCTAssertNil([[Pushwoosh inbox] getTabs]);
}

#pragma mark - Message action

/// Verifies that reporting the action of an inbox message sends its statistics with the message action parameters.
- (void)testReportActionSendsMessageStats {
    [self respondWithTabs:nil messages:@[[self messageDictWithCode:@"c1" tab:@"a1b2c3"]] error:nil];
    [self loadMessagesAndWait];
    Pushwoosh *pushwoosh = [Pushwoosh pw_sharedInstance];
    PWDataManager *originalDataManager = pushwoosh.dataManager;
    id dataManager = OCMClassMock([PWDataManager class]);
    OCMExpect([dataManager sendStatsForPush:@{@"pw_inbox_tab": @"a1b2c3"}]);
    pushwoosh.dataManager = dataManager;

    [[Pushwoosh inbox] reportActionForMessageWithCode:@"c1"];

    pushwoosh.dataManager = originalDataManager;
    OCMVerifyAll(dataManager);
}

/// Verifies that performing the action of an inbox message hands the message action parameters to the push manager.
- (void)testPerformActionRunsMessageAction {
    [self respondWithTabs:nil messages:@[[self messageDictWithCode:@"c1" tab:@"a1b2c3"]] error:nil];
    [self loadMessagesAndWait];
    Pushwoosh *pushwoosh = [Pushwoosh pw_sharedInstance];
    PWDataManager *originalDataManager = pushwoosh.dataManager;
    PWPushNotificationsManager *originalPushManager = pushwoosh.pushNotificationManager;
    id pushManager = OCMClassMock([PWPushNotificationsManager class]);
    OCMExpect([pushManager processInboxActionUserInfo:@{@"pw_inbox_tab": @"a1b2c3"}]);
    pushwoosh.dataManager = OCMClassMock([PWDataManager class]);
    pushwoosh.pushNotificationManager = pushManager;

    [[Pushwoosh inbox] performActionForMessageWithCode:@"c1"];

    pushwoosh.dataManager = originalDataManager;
    pushwoosh.pushNotificationManager = originalPushManager;
    OCMVerifyAll(pushManager);
}

@end
