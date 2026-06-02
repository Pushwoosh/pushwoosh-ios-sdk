#import "PWInboxService.h"
#import "PWInboxMessageInternal.h"
#import "PWRequestManager.h"
#import "PWInboxUpdateStatusRequest.h"

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface PWInboxService (TEST)

@property (nonatomic) PWRequestManager *requestManager;

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
