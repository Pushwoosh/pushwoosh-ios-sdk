// OCHamcrest by Jon Reid, https://qualitycoding.org
// Copyright 2022 hamcrest.org. https://github.com/hamcrest/OCHamcrest/blob/main/LICENSE.txt
// SPDX-License-Identifier: BSD-2-Clause

#import <OCHamcrest/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Is the value nil?
 */
@interface HCIsNil : HCBaseMatcher
@end


FOUNDATION_EXPORT id HC_nilValue(void);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is <code>nil</code>.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(myObject, nilValue())</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_nilValue instead.
 */
static inline id nilValue(void)
{
    return HC_nilValue();
}
#endif


FOUNDATION_EXPORT id HC_notNilValue(void);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is not <code>nil</code>.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(myObject, notNilValue())</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_notNilValue instead.
 */
static inline id notNilValue(void)
{
    return HC_notNilValue();
}
#endif

NS_ASSUME_NONNULL_END
