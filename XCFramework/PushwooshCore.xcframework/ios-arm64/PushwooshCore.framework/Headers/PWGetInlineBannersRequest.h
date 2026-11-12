//
//  PWGetInlineBannersRequest.h
//  PushwooshCore
//
//  Created by André Kis on 30.10.26.
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <PushwooshCore/PWRequest.h>

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

/// `getInlineBanners` of the device API v2: flat body, sent to `Pushwoosh_INLINE_URL` when set, else to the
/// base URL with `json/1.3/` replaced by `api/v2/device-api/`. Empty `baseUrl` = no endpoint (reverse proxy
/// without `json/1.3/`), the request must not be sent.
@interface PWGetInlineBannersRequest : PWRequest

- (instancetype)initWithSlots:(NSArray<NSString *> *)slots formats:(NSArray<NSString *> *)formats;

@property (nonatomic, readonly) NSArray<NSString *> *slots;
@property (nonatomic, readonly) NSArray<NSString *> *formats;

/// The inline endpoint for the host and application `request` is pinned to, `Pushwoosh_INLINE_URL` when set.
/// Empty = no endpoint.
+ (NSString *)endpointForRequest:(PWRequest *)request;

/// The `slots` object of the response: slot id to a banner object or `NSNull`. `nil` when the response has none.
@property (nonatomic, readonly, nullable) NSDictionary<NSString *, id> *slotsResponse;

@end

NS_ASSUME_NONNULL_END

#endif
