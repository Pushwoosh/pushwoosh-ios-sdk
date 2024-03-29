// OCHamcrest by Jon Reid, https://qualitycoding.org
// Copyright 2022 hamcrest.org. https://github.com/hamcrest/OCHamcrest/blob/main/LICENSE.txt
// SPDX-License-Identifier: BSD-2-Clause

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract A description of an HCMatcher.
 * @discussion An HCMatcher will describe itself to a description which can later be used for reporting.
 */
@protocol HCDescription <NSObject>

/*!
 * @abstract Appends some plain text to the description.
 * @return <code>self</code>, for chaining.
 */
- (id <HCDescription>)appendText:(NSString *)text;

/*!
 * @abstract Appends description of specified value to description.
 * @discussion If the value implements the HCSelfDescribing protocol, then it will be used.
 * @return <code>self</code>, for chaining.
 */
- (id <HCDescription>)appendDescriptionOf:(nullable id)value;

/*!
 * @abstract Appends a list of objects to the description.
 * @return <code>self</code>, for chaining.
 */
- (id <HCDescription>)appendList:(NSArray *)values
                          start:(NSString *)start
                      separator:(NSString *)separator
                            end:(NSString *)end;

@end

NS_ASSUME_NONNULL_END
