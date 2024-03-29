// OCHamcrest by Jon Reid, https://qualitycoding.org
// Copyright 2022 hamcrest.org. https://github.com/hamcrest/OCHamcrest/blob/main/LICENSE.txt
// SPDX-License-Identifier: BSD-2-Clause
// Contribution by Todd Farrell

#import <OCHamcrest/HCBaseMatcher.h>


NS_ASSUME_NONNULL_BEGIN

/*!
 * @abstract Matches objects that conform to specified protocol.
 */
@interface HCConformsToProtocol : HCBaseMatcher

- (instancetype)initWithProtocol:(Protocol *)protocol NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end


FOUNDATION_EXPORT id HC_conformsTo(Protocol *aProtocol);

#ifndef HC_DISABLE_SHORT_SYNTAX
/*!
 * @abstract Creates a matcher that matches when the examined object conforms to the specified
 * protocol.
 * @param aProtocol The protocol to compare against as the expected protocol.
 * @discussion
 * <b>Example</b><br />
 * <pre>assertThat(myObject, conformsTo(\@protocol(NSCoding))</pre>
 *
 * <b>Name Clash</b><br />
 * In the event of a name clash, <code>#define HC_DISABLE_SHORT_SYNTAX</code> and use the synonym
 * HC_conformsTo instead.
 */
static inline id conformsTo(Protocol *aProtocol)
{
    return HC_conformsTo(aProtocol);
}
#endif

NS_ASSUME_NONNULL_END
