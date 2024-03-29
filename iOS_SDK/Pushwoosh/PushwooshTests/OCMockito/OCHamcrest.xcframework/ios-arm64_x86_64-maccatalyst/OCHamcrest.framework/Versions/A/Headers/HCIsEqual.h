// OCHamcrest by Jon Reid, https://qualitycoding.org
// Copyright 2022 hamcrest.org. https://github.com/hamcrest/OCHamcrest/blob/main/LICENSE.txt
// SPDX-License-Identifier: BSD-2-Clause

#import <OCHamcrest/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Is the value equal to another value, as tested by the <code>-isEqual:</code> method?
 */
@interface HCIsEqual : HCBaseMatcher

- (instancetype)initEqualTo:(nullable id)expectedValue NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


FOUNDATION_EXPORT id HC_equalTo(_Nullable id operand);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is equal to the specified
 * object, as determined by calling the <code>-isEqual:</code> method on the <b>examined</b> object.
 * @param operand The object to compare against as the expected value.
 * @discussion If the specified operand is <code>nil</code>, then the created matcher will match if
 * the examined object itself is <code>nil</code>, or if the examined object's <code>-isEqual:</code>
 * method returns <code>YES</code> when passed a <code>nil</code>.
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_equalTo instead.
 */
static inline id equalTo(_Nullable id operand)
{
    return HC_equalTo(operand);
}
#endif

NS_ASSUME_NONNULL_END
