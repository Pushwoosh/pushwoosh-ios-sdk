// OCHamcrest by Jon Reid, https://qualitycoding.org
// Copyright 2022 hamcrest.org. https://github.com/hamcrest/OCHamcrest/blob/main/LICENSE.txt
// SPDX-License-Identifier: BSD-2-Clause

#import <OCHamcrest/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Calculates the logical disjunction of multiple matchers.
 * @discussion Evaluation is shortcut, so subsequent matchers are not called if an earlier matcher
 * returns <code>NO</code>.
 */
@interface HCAnyOf : HCBaseMatcher

- (instancetype)initWithMatchers:(NSArray<id <HCMatcher>> *)matchers NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

FOUNDATION_EXPORT id HC_anyOfIn(NSArray *matchers);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object matches <b>any</b> of the
 * specified matchers.
 * @param matchers An array of matchers. Any element that is not a matcher is implicitly wrapped in
 * an <em>equalTo</em> matcher to check for equality.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@"myValue", allOf(\@[startsWith(\@"foo"), containsSubstring(\@"Val")]))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_anyOf instead.
 */
static inline id anyOfIn(NSArray *matchers)
{
    return HC_anyOfIn(matchers);
}
#endif

FOUNDATION_EXPORT id HC_anyOf(id matchers, ...) NS_REQUIRES_NIL_TERMINATION;

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object matches <b>any</b> of the
 * specified matchers.
 * @param matchers... A comma-separated list of matchers ending with <code>nil</code>. Any argument
 * that is not a matcher is implicitly wrapped in an <em>equalTo</em> matcher to check for equality.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(\@"myValue", allOf(startsWith(\@"foo"), containsSubstring(\@"Val"), nil))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_anyOf instead.
 */
#define anyOf(matchers...) HC_anyOf(matchers)
#endif

NS_ASSUME_NONNULL_END
