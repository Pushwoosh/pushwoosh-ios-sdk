// OCHamcrest by Jon Reid, https://qualitycoding.org
// Copyright 2022 hamcrest.org. https://github.com/hamcrest/OCHamcrest/blob/main/LICENSE.txt
// SPDX-License-Identifier: BSD-2-Clause

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 @abstract Test failure location and reason.
 */
@interface HCTestFailure : NSObject

/*!
 * @abstract Test case used to run test method.
 * @discussion Can be <code>nil</code>.
 *
 * For unmet OCHamcrest assertions, if the assertion was <code>assertThat</code> or
 * <code>assertWithTimeout</code>, <em>testCase</em> will be the test case instance.
 */
@property (nonatomic, strong, readonly) id testCase;

/*! @abstract File name to report. */
@property (nonatomic, copy, readonly) NSString *fileName;

/*! @abstract Line number to report. */
@property (nonatomic, assign, readonly) NSUInteger lineNumber;

/*! @abstract Failure reason to report. */
@property (nonatomic, strong, readonly) NSString *reason;

/*!
 * @abstract Initializes a newly allocated instance of a test failure.
 */
- (instancetype)initWithTestCase:(id)testCase
                        fileName:(NSString *)fileName
                      lineNumber:(NSUInteger)lineNumber
                          reason:(NSString *)reason;

@end

NS_ASSUME_NONNULL_END
