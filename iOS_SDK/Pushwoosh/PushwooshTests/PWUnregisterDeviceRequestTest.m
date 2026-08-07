//
//  PWUnregisterDeviceRequestTest.m
//  PushwooshTests
//
//  Created by Kiselev Andrey on 25.01.2022.
//  Copyright © 2022 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "PWUnregisterDeviceRequest.h"
#import "PWRequest+Internal.h"
#import "PWPreferences.h"

@interface PWUnregisterDeviceRequest (TEST)

- (BOOL)isLoggable;
- (NSString *)methodName;

@end

@interface PWUnregisterDeviceRequestTest : XCTestCase

@property (nonatomic) PWUnregisterDeviceRequest *request;
@property (nonatomic, copy) NSString *savedAppCode;
@property (nonatomic, copy) NSString *savedUserId;

@end

@implementation PWUnregisterDeviceRequestTest

- (void)setUp {
    _request = [[PWUnregisterDeviceRequest alloc] init];
    _savedAppCode = [[PWPreferences preferences].appCode copy];
    _savedUserId = [[PWPreferences preferences].userId copy];
}

- (void)tearDown {
    [PWPreferences preferences].appCode = _savedAppCode;
    if (_savedUserId) {
        [PWPreferences preferences].userId = _savedUserId;
    }
}

- (void)testCorrectMethodName {
    NSString *methodName = [self.request methodName];

    XCTAssertEqualObjects(methodName, @"unregisterDevice");
}

/// SDK-882: Verifies that a pinned request serializes the pinned application code and targets the pinned host, not the live values.
- (void)testPinnedRequestCarriesPinnedPair {
    _request.pinnedAppCode = @"PREV-11111";
    _request.pinnedBaseUrl = @"https://previous.example.com/json/1.3/";

    XCTAssertEqualObjects([_request requestDictionary][@"application"], @"PREV-11111");
    XCTAssertEqualObjects([_request baseUrl], @"https://previous.example.com/json/1.3/");
}

/// SDK-882: Verifies that an unpinned request still serializes the live application code and has no base URL override.
- (void)testUnpinnedRequestUsesLiveApplicationCode {
    [PWPreferences preferences].appCode = @"LIVE-11111";

    XCTAssertEqualObjects([_request requestDictionary][@"application"], @"LIVE-11111");
    XCTAssertNil([_request baseUrl]);
}

/// SDK-882: Verifies that a pinned user id is serialized instead of the live one, so a setUserId: landing before the send cannot re-address the request.
- (void)testPinnedRequestCarriesPinnedUserId {
    [PWPreferences preferences].userId = @"user-at-pin-time";
    _request.pinnedUserId = [PWPreferences preferences].userId;

    [PWPreferences preferences].userId = @"user-set-afterwards";

    XCTAssertEqualObjects([_request requestDictionary][@"userId"], @"user-at-pin-time");
}

/// SDK-882: Verifies that an unpinned request still serializes the live user id — every ordinary request must follow it.
- (void)testUnpinnedRequestUsesLiveUserId {
    [PWPreferences preferences].userId = @"live-user";

    XCTAssertEqualObjects([_request requestDictionary][@"userId"], @"live-user");
}

@end
