//
//  PWAlphabetUtilsTests.m
//  PushwooshTests
//
//  Created by André Kis on 29.10.24.
//  Copyright © 2024 Pushwoosh. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "PWAlphabetUtils.h"

@interface PWAlphabetUtilsTests : XCTestCase

@end

@implementation PWAlphabetUtilsTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [PWAlphabetUtils initialize];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testAlphabetInitialization {
    NSDictionary<NSNumber *, NSString *> *alphabet = [PWAlphabetUtils alphabet];
    XCTAssertEqual(alphabet.count, 62, @"alphabet should contain exactly 62 elements");

    XCTAssertEqualObjects(alphabet[@0], @"0", @"Incorrect value for key 0 in alphabet");
    XCTAssertEqualObjects(alphabet[@61], @"Z", @"Incorrect value for key 61 in alphabet");
}

- (void)testAlphabetRevertInitialization {
    NSDictionary<NSNumber *, NSString *> *alphabet = [PWAlphabetUtils alphabet];
    NSDictionary<NSString *, NSNumber *> *alphabetRevert = [PWAlphabetUtils alphabetRevert];

    for (NSNumber *key in alphabet) {
        NSString *value = alphabet[key];
        XCTAssertEqualObjects(alphabetRevert[value], key, @"Incorrect reverse mapping for key %@", key);
    }
}

- (void)testAlphabetDecodeWithEmptyString {
    uint64_t result = [PWAlphabetUtils alphabetDecode:@""];
    XCTAssertEqual(result, 0, @"Decoding an empty string should return 0");
}

- (void)testAlphabetDecodeWithValidString {
    uint64_t result = [PWAlphabetUtils alphabetDecode:@"a1"];
    
    XCTAssertEqual(result, 621, @"Decoding 'a1' should return 621");
}

- (void)testAlphabetDecodeWithInvalidString {
    uint64_t result = [PWAlphabetUtils alphabetDecode:@"a@"];
    
    XCTAssertEqual(result, 0, @"Decoding a string with invalid characters should return 0");
}

- (void)testAlphabetDecodeWithSingleCharacter {
    uint64_t result = [PWAlphabetUtils alphabetDecode:@"Z"];
    
    XCTAssertEqual(result, 61, @"Decoding 'Z' should return 61");
}

- (void)testAlphabetDecodeWithMultipleCharacters {
    uint64_t result = [PWAlphabetUtils alphabetDecode:@"Zz9"];
    
    XCTAssertEqual(result, 236663, @"Decoding 'Zz9' should return 235295");
}

@end
