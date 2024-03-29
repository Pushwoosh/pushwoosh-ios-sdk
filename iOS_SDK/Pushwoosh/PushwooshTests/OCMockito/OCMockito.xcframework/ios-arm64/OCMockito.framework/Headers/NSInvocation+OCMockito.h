// OCMockito by Jon Reid, https://qualitycoding.org
// Copyright 2022 Jonathan M. Reid. https://github.com/jonreid/OCMockito/blob/main/LICENSE.txt
// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract NSInvocation helper methods
 */
@interface NSInvocation (OCMockito)

/*!
 * @abstract Returns all invocation arguments in an NSArray.
 * @discussion Non-object arguments are boxed as follows:
 * <ul>
 *   <li><code>nil</code>: NSNull</li>
 *   <li>Primitive numeric values: NSNumber</li>
 *   <li>Pointers: NSValue</li>
 *   <li>Selectors: NSString</li>
 *   <li>Structs: NSData</li>
 * </ul>
 */
- (NSArray *)mkt_arguments;

/*! @abstract Sets invocation return value. */
- (void)mkt_setReturnValue:(nullable id)returnValue;

/*! @abstract Retains arguments but with weak invocation target to avoid retain cycles. */
- (void)mkt_retainArgumentsWithWeakTarget;

@end

NS_ASSUME_NONNULL_END
