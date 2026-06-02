#import <XCTest/XCTest.h>
#import "PWAlphabetUtils.h"

@interface PWAlphabetUtilsTests : XCTestCase

@end

@implementation PWAlphabetUtilsTests

- (void)setUp {
    [super setUp];
    [PWAlphabetUtils initialize];
}

/// Verifies that the alphabet table contains exactly 62 entries with 0->"0" and 61->"Z" anchors.
- (void)testAlphabetInitialization {
    NSDictionary<NSNumber *, NSString *> *alphabet = [PWAlphabetUtils alphabet];
    XCTAssertEqual(alphabet.count, 62);
    XCTAssertEqualObjects(alphabet[@0], @"0");
    XCTAssertEqualObjects(alphabet[@61], @"Z");
}

/// Verifies that alphabetRevert is the inverse mapping of alphabet for every key.
- (void)testAlphabetRevertInitialization {
    NSDictionary<NSNumber *, NSString *> *alphabet = [PWAlphabetUtils alphabet];
    NSDictionary<NSString *, NSNumber *> *alphabetRevert = [PWAlphabetUtils alphabetRevert];

    for (NSNumber *key in alphabet) {
        NSString *value = alphabet[key];
        XCTAssertEqualObjects(alphabetRevert[value], key, @"Incorrect reverse mapping for key %@", key);
    }
}

/// Verifies that alphabetDecode returns 0 for an empty input string.
- (void)testAlphabetDecodeWithEmptyString {
    XCTAssertEqual([PWAlphabetUtils alphabetDecode:@""], 0);
}

/// Verifies that alphabetDecode treats "a1" as base-62 ("a"=10, "1"=1) -> 10*62+1 = 621.
- (void)testAlphabetDecodeWithValidString {
    XCTAssertEqual([PWAlphabetUtils alphabetDecode:@"a1"], 621);
}

/// Verifies that alphabetDecode returns 0 when the input contains characters outside the alphabet.
- (void)testAlphabetDecodeWithInvalidString {
    XCTAssertEqual([PWAlphabetUtils alphabetDecode:@"a@"], 0);
}

/// Verifies that alphabetDecode of the highest single character ("Z") returns 61.
- (void)testAlphabetDecodeWithSingleCharacter {
    XCTAssertEqual([PWAlphabetUtils alphabetDecode:@"Z"], 61);
}

/// Verifies that alphabetDecode of "Zz9" computes the expected base-62 value.
- (void)testAlphabetDecodeWithMultipleCharacters {
    XCTAssertEqual([PWAlphabetUtils alphabetDecode:@"Zz9"], 236663);
}

@end
