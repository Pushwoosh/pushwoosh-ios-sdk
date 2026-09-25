#import "PWInboxService.h"
#import "PWInboxMessageInternal.h"
#import "PWRequestManager.h"
#import "PWInboxUpdateStatusRequest.h"

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface PWInboxService (TEST)

@property (nonatomic) PWRequestManager *requestManager;

/// Stubbed in tests: it talks to UNUserNotificationCenter and has nothing to do with
/// the request under test.
- (void)removeMessagesFromNotificationCenter:(NSArray<PWInboxMessageInternal *> *)messages;

@end

@interface PWInboxUpdateStatusRequest (TEST)

+ (instancetype)deleteInboxMessage:(NSString *)inboxCode inboxHash:(NSString *)inboxHash;

@end

@interface PWInboxServiceTest : XCTestCase

@property (nonatomic) PWInboxService *service;
@property (nonatomic) NSString *code;
@property (nonatomic) NSString *imageUrl;
@property (nonatomic) NSNumber *type;

@end

@implementation PWInboxServiceTest

- (void)setUp {
    [super setUp];
    _code = @"ASDF-ASD_ADAS";
    _imageUrl = @"image_url";
    _type = @0;
    _service = [[PWInboxService alloc] init];
}

/// Verifies that sendStatusInDiffMessages does not flip deleted/isActionPerformed/isRead on a message whose canUpdateStatus stub blocks mutation while isFromNotification is NO.
- (void)testIsFromNotificationFalseSendRequestMessageDeleted {
    PWInboxMessageInternal *message = [PWInboxMessageInternal messageWithPushNotification:self.parameters];
    NSArray <PWInboxMessageInternal *> *arrayMessages = @[message];
    id mockPWInboxMessageInternal = OCMPartialMock(message);
    OCMStub([mockPWInboxMessageInternal canUpdateStatus]).andReturn(YES);
    OCMStub([mockPWInboxMessageInternal isFromNotification]).andReturn(NO);
    OCMStub([mockPWInboxMessageInternal deleted]).andReturn(NO);
    OCMStub([mockPWInboxMessageInternal isActionPerformed]).andReturn(NO);
    OCMStub([mockPWInboxMessageInternal isRead]).andReturn(NO);

    [self.service sendStatusInDiffMessages:arrayMessages];

    XCTAssertFalse(message.deleted);
    XCTAssertFalse(message.isActionPerformed);
    XCTAssertFalse(message.isRead);

    [mockPWInboxMessageInternal stopMocking];
}

#pragma mark - SDK-998: the status 3 packet

/// The packet Control Panel counts opens by, asserted where the SDK hands it to the
/// transport — the last point that is still the SDK and not the network.
- (void)testActionMessagesSendsStatusThreeWithTheMessageSortOrder {
    PWInboxMessageInternal *message = [self messageWithSortOrder];
    __block PWInboxUpdateStatusRequest *sent = nil;
    id requestManager = OCMClassMock([PWRequestManager class]);
    OCMStub([requestManager sendRequest:[OCMArg checkWithBlock:^BOOL(id request) {
        sent = request;
        return YES;
    }] completion:[OCMArg any]]);
    id service = OCMPartialMock(self.service);
    OCMStub([service removeMessagesFromNotificationCenter:OCMOCK_ANY]);
    self.service.requestManager = requestManager;

    [self.service actionMessages:@[message]];

    XCTAssertTrue([sent isKindOfClass:[PWInboxUpdateStatusRequest class]], @"the open never left for the backend");
    XCTAssertEqual([[sent valueForKey:@"status"] integerValue], 3, @"Control Panel counts opens by status 3");
    XCTAssertEqualObjects([sent valueForKey:@"inboxCode"], message.sortOrder);

    [service stopMocking];
}

/// Negative control: with no sortOrder there is nowhere to send, so nothing is sent.
/// Without it the test above would pass against a stub that fires on everything.
- (void)testActionMessagesSkipsAMessageWithoutSortOrder {
    PWInboxMessageInternal *message = [PWInboxMessageInternal messageWithPushNotification:self.parameters];
    id requestManager = OCMClassMock([PWRequestManager class]);
    OCMReject([requestManager sendRequest:OCMOCK_ANY completion:OCMOCK_ANY]);
    id service = OCMPartialMock(self.service);
    OCMStub([service removeMessagesFromNotificationCenter:OCMOCK_ANY]);
    self.service.requestManager = requestManager;

    XCTAssertNil(message.sortOrder, @"case built wrong: the message must have no sortOrder");
    [self.service actionMessages:@[message]];

    [service stopMocking];
}

- (PWInboxMessageInternal *)messageWithSortOrder {
    // Every key here is required by +validateDictionary:, which returns nil for the whole
    // message if one is missing — status included, easy to leave out and hard to read back.
    PWInboxMessageInternal *message = [PWInboxMessageInternal messageWithDictionary:@{
        @"inbox_id": _code,
        @"order": @1,
        @"rt": @2000000000,
        @"send_date": @1700000000,
        @"text": @"text",
        @"title": @"title",
        @"action_type": _type,
        @"status": @(PWInboxMessageStatusDelivered),
    }];
    XCTAssertNotNil(message, @"the fixture is invalid, not the code under test");
    return message;
}

- (NSDictionary *)parameters {
    return @{
        @"pw_inbox": _code,
        @"inbox_params": @{
            @"rt": @"1646917972",
            @"image": _imageUrl,
        },
        @"aps": @{
            @"alert": @{
                @"alert": @"alert",
                @"title": @"test",
                @"body": @"test",
            },
        },
        @"action_type": _type
    };
}

@end
