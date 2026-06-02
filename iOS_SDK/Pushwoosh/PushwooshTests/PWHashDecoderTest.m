#import <XCTest/XCTest.h>
#import "PWHashDecoder.h"
#import "PWAlphabetUtils.h"

@interface PWHashDecoderTest : XCTestCase

@property (nonatomic, strong) PWHashDecoder *hashDecoder;

@end

@interface PWHashDecoder (TEST)

- (NSString *)prependZerosIfNeeded:(BOOL)isFirstPart hexNumber:(NSString *)hexNumber;
- (NSString *)decodeMessageCode:(NSString *)messageCode;

@end

@implementation PWHashDecoderTest

- (void)setUp {
    [super setUp];
    self.hashDecoder = [[PWHashDecoder alloc] init];
    [PWAlphabetUtils initialize];
}

#pragma mark - prependZerosIfNeeded:hexNumber:

/// Verifies that a hex number already at first-part length is returned unchanged.
- (void)testPrependZerosIfNeededWhenNoPaddingIsRequired {
    XCTAssertEqualObjects([self.hashDecoder prependZerosIfNeeded:YES hexNumber:@"1234"], @"1234");
}

/// Verifies that a short hex number is left-padded with zeros to reach the first-part length.
- (void)testPrependZerosIfNeededWhenPaddingIsRequiredForFirstPart {
    XCTAssertEqualObjects([self.hashDecoder prependZerosIfNeeded:YES hexNumber:@"12"], @"0012");
}

/// Verifies that an other-part hex number is left-padded with zeros to reach the other-part length.
- (void)testPrependZerosIfNeededWhenPaddingIsRequiredForOtherPart {
    XCTAssertEqualObjects([self.hashDecoder prependZerosIfNeeded:NO hexNumber:@"12345"], @"00012345");
}

#pragma mark - decodeMessageCode:

/// Verifies that a single-part code (no dash) is returned unchanged.
- (void)testDecodeMessageCodeWithSinglePart {
    XCTAssertEqualObjects([self.hashDecoder decodeMessageCode:@"abcd"], @"abcd");
}

/// Verifies that a multi-part code "a-1" is uppercased and each part padded to its segment length.
- (void)testDecodeMessageCodeWithMultipleParts {
    XCTAssertEqualObjects([self.hashDecoder decodeMessageCode:@"a-1"], @"000A-00000001");
}

#pragma mark - parseMessageHash:

/// Verifies that an unrecognized hash format resets messageCode/messageId/campaignId to zero values.
- (void)testParseMessageHashWithInvalidHash {
    [self.hashDecoder parseMessageHash:@"invalid_hash"];

    XCTAssertEqualObjects(self.hashDecoder.messageCode, @"");
    XCTAssertEqual(self.hashDecoder.messageId, 0);
    XCTAssertEqual(self.hashDecoder.campaignId, 0);
}

/// Verifies that a "_<campaign>_<message>_<code>" hash parses campaignId and messageId from the base-62 segments.
- (void)testParseMessageHashWithValidHash {
    [self.hashDecoder parseMessageHash:@"_1_2_ab-cd"];

    XCTAssertEqual(self.hashDecoder.campaignId, 1);
    XCTAssertEqual(self.hashDecoder.messageId, 2);
}

/// Verifies that a hash shorter than the expected layout resets messageCode/messageId/campaignId to zero values.
- (void)testParseMessageHashWithShortHash {
    [self.hashDecoder parseMessageHash:@"short"];

    XCTAssertEqualObjects(self.hashDecoder.messageCode, @"");
    XCTAssertEqual(self.hashDecoder.messageId, 0);
    XCTAssertEqual(self.hashDecoder.campaignId, 0);
}

@end
