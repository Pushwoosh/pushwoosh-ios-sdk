//
//  PWHashDecoderTest.m
//  PushwooshTests
//
//  Created by André Kis on 29.10.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PWHashDecoder.h"
#import "PWAlphabetUtils.h"

@interface PWHashDecoderTest : XCTestCase

@property (nonatomic, strong) PWHashDecoder *hashDecoder;

@end

@interface PWHashDecoder(TEST)

- (NSString *)prependZerosIfNeeded:(BOOL)isFirstPart hexNumber:(NSString *)hexNumber;
- (NSString *)decodeMessageCode:(NSString *)messageCode;

@end

@implementation PWHashDecoderTest

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.hashDecoder = [[PWHashDecoder alloc] init];
    [PWAlphabetUtils initialize];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

#pragma mark - Tests for prependZerosIfNeeded:hexNumber:
#pragma mark -

- (void)testPrependZerosIfNeededWhenNoPaddingIsRequired {
    NSString *result = [self.hashDecoder prependZerosIfNeeded:YES hexNumber:@"1234"];
    
    XCTAssertEqualObjects(result, @"1234", @"Should return the hex number as is when no padding is required.");
}

- (void)testPrependZerosIfNeededWhenPaddingIsRequiredForFirstPart {
    NSString *result = [self.hashDecoder prependZerosIfNeeded:YES hexNumber:@"12"];
    
    XCTAssertEqualObjects(result, @"0012", @"Should prepend zeros to reach first part length.");
}

- (void)testPrependZerosIfNeededWhenPaddingIsRequiredForOtherPart {
    NSString *result = [self.hashDecoder prependZerosIfNeeded:NO hexNumber:@"12345"];
    
    XCTAssertEqualObjects(result, @"00012345", @"Should prepend zeros to reach other part length.");
}

#pragma mark - Tests for decodeMessageCode:
#pragma mark -

- (void)testDecodeMessageCodeWithSinglePart {
    NSString *result = [self.hashDecoder decodeMessageCode:@"abcd"];
    
    XCTAssertEqualObjects(result, @"abcd", @"Should return the input as is for single-part message code.");
}

- (void)testDecodeMessageCodeWithMultipleParts {
    NSString *result = [self.hashDecoder decodeMessageCode:@"a-1"];

    XCTAssertEqualObjects(result, @"000A-00000001", @"Should decode multiple parts and prepend zeros as needed.");
}

#pragma mark - Tests for parseMessageHash:
#pragma mark -

- (void)testParseMessageHashWithInvalidHash {
    [self.hashDecoder parseMessageHash:@"invalid_hash"];
    
    XCTAssertEqualObjects(self.hashDecoder.messageCode, @"", @"Invalid hash should reset messageCode.");
    XCTAssertEqual(self.hashDecoder.messageId, 0, @"Invalid hash should reset messageId.");
    XCTAssertEqual(self.hashDecoder.campaignId, 0, @"Invalid hash should reset campaignId.");
}

- (void)testParseMessageHashWithValidHash {
    NSString *validHash = @"_1_2_ab-cd";
    
    [self.hashDecoder parseMessageHash:validHash];

    XCTAssertEqual(self.hashDecoder.campaignId, 1, @"Parsed campaignId should match expected value.");
    XCTAssertEqual(self.hashDecoder.messageId, 2, @"Parsed messageId should match expected value.");
}

- (void)testParseMessageHashWithShortHash {
    [self.hashDecoder parseMessageHash:@"short"];
    
    XCTAssertEqualObjects(self.hashDecoder.messageCode, @"", @"Short hash should reset messageCode.");
    XCTAssertEqual(self.hashDecoder.messageId, 0, @"Short hash should reset messageId.");
    XCTAssertEqual(self.hashDecoder.campaignId, 0, @"Short hash should reset campaignId.");
}

@end
