//
//  PWInboxMessageInternalTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 10.03.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import "PWInboxMessageInternal.h"
#import "PWInbox.h"

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

@interface PWInboxMessageInternalTest : XCTestCase

@property (nonatomic) NSString *code;
@property (nonatomic) NSString *imageUrl;
@property (nonatomic) NSNumber *type;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *message;

@end

@implementation PWInboxMessageInternalTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    _code = @"ASDF-ASD_ADAS";
    _imageUrl = @"image_url";
    _type = @0;
    _title = @"test";
    _message = @"test";
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testIsFromNotificationTrue {
    PWInboxMessageInternal *internal = [PWInboxMessageInternal messageWithPushNotification:self.parameters];

    XCTAssertEqual(internal.code, @"ASDF-ASD_ADAS");
    XCTAssertEqual(internal.type, 0);
    XCTAssertEqual(internal.imageUrl, _imageUrl);
    XCTAssertEqual(internal.title, _title);
    XCTAssertEqual(internal.message, _message);
    XCTAssertTrue(internal.isFromNotification);
}

- (void)testIsFromNotificationMethod {
    PWInboxMessageInternal *message = [PWInboxMessageInternal messageWithPushNotification:self.parameters];
    
    BOOL isFromNotification = [PWInboxMessageInternal isFromNotification:message];
    
    XCTAssertTrue(isFromNotification);
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
