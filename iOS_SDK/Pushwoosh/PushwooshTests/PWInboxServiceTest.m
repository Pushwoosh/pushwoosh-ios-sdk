//
//  PWInboxServiceTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 10.03.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

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
@property (nonatomic) id mockInboxService;

@property (nonatomic) NSString *code;
@property (nonatomic) NSString *imageUrl;
@property (nonatomic) NSNumber *type;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *message;

@end

@implementation PWInboxServiceTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _code = @"ASDF-ASD_ADAS";
    _imageUrl = @"image_url";
    _type = @0;
    _title = @"test";
    _message = @"test";
    
    _service = [[PWInboxService alloc] init];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

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
    return @{@"pw_inbox": _code,
                                 @"inbox_params": @{@"rt": @"1646917972",
                                                    @"image": _imageUrl,
                                 },
                                 @"aps": @{@"alert": @{@"alert": @"alert",
                                                       @"title": @"test",
                                                       @"body": @"test",
                                 },
                                 },
                                 @"action_type": _type
    };
}

@end
