//
//  PWTrackInlineEventRequest.h
//  PushwooshCore
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <PushwooshCore/PWRequest.h>

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

/// `trackInlineEvent` of the device API v2: flat body of the device fields and the event, sent to the endpoint of
/// `PWGetInlineBannersRequest`. Empty `baseUrl` = no endpoint, the request must not be sent. A failed send is queued
/// for retry on the same host; offline it waits for the network without spending attempts; at most 100 such events
/// stay queued, the oldest are dropped.
@interface PWTrackInlineEventRequest : PWRequest

- (instancetype)initWithEvent:(NSDictionary<NSString *, id> *)event;

@end

NS_ASSUME_NONNULL_END

#endif
