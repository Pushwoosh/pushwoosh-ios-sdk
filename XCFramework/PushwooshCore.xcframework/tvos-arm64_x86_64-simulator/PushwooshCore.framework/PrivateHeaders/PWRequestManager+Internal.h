//
//  PWRequestManager+Internal.h
//  PushwooshCore
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <PushwooshCore/PWRequestManager.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWRequestManager (Internal)

/// The exact NSURLRequest the REST transport sends for `request` (URL, body and headers, reverse proxy applied),
/// so it can be handed to another session. nil with `error` when no base URL is set or the body does not serialize.
- (nullable NSURLRequest *)urlRequestForRequest:(PWRequest *)request error:(NSError * _Nullable * _Nullable)error;

@end

NS_ASSUME_NONNULL_END
