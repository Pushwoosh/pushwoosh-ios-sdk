// OCHamcrest by Jon Reid, https://qualitycoding.org
// Copyright 2022 hamcrest.org. https://github.com/hamcrest/OCHamcrest/blob/main/LICENSE.txt
// SPDX-License-Identifier: BSD-2-Clause

#import <OCHamcrest/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Matches if examined object is contained within the nested collection.
 */
@interface HCIsIn : HCBaseMatcher

- (instancetype)initWithCollection:(id)collection NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


FOUNDATION_EXPORT id HC_isIn(id aCollection);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object is found within the specified
 * collection.
 * @param aCollection The collection to search.
 * @discussion Invokes <code>-containsObject:</code> on <em>aCollection</em> to determine if the
 * examined object is an element of the collection.
 *
 * <b>Example</b><br />
 * <pre>assertThat(\@"foo", isIn(\@@[\@"bar", \@"foo"]))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_isIn instead.
 */
static inline id isIn(id aCollection)
{
    return HC_isIn(aCollection);
}
#endif

NS_ASSUME_NONNULL_END
