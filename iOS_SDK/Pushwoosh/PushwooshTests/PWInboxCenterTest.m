//  PWInboxCenterTest.m
//  Created by André Kis

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "PWInbox.h"
#import "PushwooshFramework.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface PWInboxCenterTest : XCTestCase

@property (nonatomic) id inboxMock;

@end

@implementation PWInboxCenterTest

- (void)setUp {
    [super setUp];
    self.inboxMock = OCMClassMock([PWInbox class]);
}

- (void)tearDown {
    [self.inboxMock stopMocking];
    [super tearDown];
}

/// Verifies that the completion-based calls of Pushwoosh.inbox hand the caller's completion to the matching PWInbox call.
- (void)testCompletionCallsReachPWInbox {
    void (^noActionCount)(NSInteger, NSError *) = ^(NSInteger count, NSError *error) {};
    void (^unreadCount)(NSInteger, NSError *) = ^(NSInteger count, NSError *error) {};
    void (^totalCount)(NSInteger, NSError *) = ^(NSInteger count, NSError *error) {};
    void (^load)(NSArray<NSObject<PWInboxMessageProtocol> *> *, NSError *) = ^(NSArray *messages, NSError *error) {};
    void (^resync)(NSUInteger) = ^(NSUInteger messagesCount) {};
    OCMExpect([self.inboxMock messagesWithNoActionPerformedCountWithCompletion:noActionCount]);
    OCMExpect([self.inboxMock unreadMessagesCountWithCompletion:unreadCount]);
    OCMExpect([self.inboxMock messagesCountWithCompletion:totalCount]);
    OCMExpect([self.inboxMock loadMessagesWithCompletion:load]);
    OCMExpect([self.inboxMock updateInboxForNewUserId:resync]);

    [[Pushwoosh inbox] messagesWithNoActionPerformedCountWithCompletion:noActionCount];
    [[Pushwoosh inbox] unreadMessagesCountWithCompletion:unreadCount];
    [[Pushwoosh inbox] messagesCountWithCompletion:totalCount];
    [[Pushwoosh inbox] loadMessagesWithCompletion:load];
    [[Pushwoosh inbox] updateInboxForNewUserId:resync];

    OCMVerifyAll(self.inboxMock);
}

/// Verifies that the read, delete and action calls of Pushwoosh.inbox reach the matching PWInbox call with the same codes.
- (void)testMessageCallsReachPWInbox {
    NSArray<NSString *> *readCodes = @[@"r1", @"r2"];
    NSArray<NSString *> *deletedCodes = @[@"d1"];
    OCMExpect([self.inboxMock readMessagesWithCodes:readCodes]);
    OCMExpect([self.inboxMock deleteMessagesWithCodes:deletedCodes]);
    OCMExpect([self.inboxMock markAllMessagesAsRead]);
    OCMExpect([self.inboxMock deleteAllReadMessages]);
    OCMExpect([self.inboxMock performActionForMessageWithCode:@"performed"]);
    OCMExpect([self.inboxMock reportActionForMessageWithCode:@"reported"]);

    [[Pushwoosh inbox] readMessagesWithCodes:readCodes];
    [[Pushwoosh inbox] deleteMessagesWithCodes:deletedCodes];
    [[Pushwoosh inbox] markAllMessagesAsRead];
    [[Pushwoosh inbox] deleteAllReadMessages];
    [[Pushwoosh inbox] performActionForMessageWithCode:@"performed"];
    [[Pushwoosh inbox] reportActionForMessageWithCode:@"reported"];

    OCMVerifyAll(self.inboxMock);
}

/// Verifies that the synchronous reads of Pushwoosh.inbox return what PWInbox returns.
- (void)testReadsReturnPWInboxResults {
    PWInboxTabs *tabs = OCMClassMock([PWInboxTabs class]);
    id<PWInboxMessageProtocol> message = OCMProtocolMock(@protocol(PWInboxMessageProtocol));
    OCMStub([self.inboxMock getTabs]).andReturn(tabs);
    OCMStub([self.inboxMock messageForCode:@"c1"]).andReturn(message);

    XCTAssertEqual([[Pushwoosh inbox] getTabs], tabs);
    XCTAssertEqual([[Pushwoosh inbox] messageForCode:@"c1"], message);
}

/// Verifies that the subscriptions of Pushwoosh.inbox return the PWInbox observer tokens and unsubscribe through PWInbox.
- (void)testObserversUsePWInboxTokens {
    NSObject *pushToken = [NSObject new];
    NSObject *updateToken = [NSObject new];
    NSObject *unreadToken = [NSObject new];
    NSObject *noActionToken = [NSObject new];
    void (^pushBlock)(NSArray<NSObject<PWInboxMessageProtocol> *> *) = ^(NSArray *messagesAdded) {};
    void (^updateBlock)(NSArray *, NSArray *, NSArray *) = ^(NSArray *deleted, NSArray *added, NSArray *updated) {};
    void (^countBlock)(NSUInteger) = ^(NSUInteger count) {};
    OCMStub([self.inboxMock addObserverForDidReceiveInPushNotificationCompletion:pushBlock]).andReturn(pushToken);
    OCMStub([self.inboxMock addObserverForUpdateInboxMessagesCompletion:updateBlock]).andReturn(updateToken);
    OCMStub([self.inboxMock addObserverForUnreadMessagesCountUsingBlock:countBlock]).andReturn(unreadToken);
    OCMStub([self.inboxMock addObserverForNoActionPerformedMessagesCountUsingBlock:countBlock]).andReturn(noActionToken);
    OCMExpect([self.inboxMock removeObserver:updateToken]);

    XCTAssertEqual([[Pushwoosh inbox] addObserverForDidReceiveInPushNotificationCompletion:pushBlock], pushToken);
    XCTAssertEqual([[Pushwoosh inbox] addObserverForUpdateInboxMessagesCompletion:updateBlock], updateToken);
    XCTAssertEqual([[Pushwoosh inbox] addObserverForUnreadMessagesCountUsingBlock:countBlock], unreadToken);
    XCTAssertEqual([[Pushwoosh inbox] addObserverForNoActionPerformedMessagesCountUsingBlock:countBlock], noActionToken);
    [[Pushwoosh inbox] removeObserver:updateToken];

    OCMVerifyAll(self.inboxMock);
}

@end

#pragma clang diagnostic pop
