//
//  PWRequest+Internal.h
//  PushwooshCore
//
//  Created by André Kis
//  Copyright © 2026 Pushwoosh. All rights reserved.
//

#import <PushwooshCore/PWRequest.h>

NS_ASSUME_NONNULL_BEGIN

@interface PWRequest (Internal)

/// Application code frozen when the request was first handed to `PWRequestManager`.
/// `nil` = not pinned (legacy / direct call) and the live value is used instead.
@property (nonatomic, copy, nullable) NSString *pinnedAppCode;

/// API base URL frozen when the request was first handed to `PWRequestManager`. Returned by
/// `-baseUrl` unless a subclass overrides it, so a request never follows a later switch.
@property (nonatomic, copy, nullable) NSString *pinnedBaseUrl;

/// User id frozen by the request's creator. `nil` = not pinned (live value used). Set only for the
/// unregister from the vacated application; `-pinApplicationForRequest:` deliberately never sets this.
@property (nonatomic, copy, nullable) NSString *pinnedUserId;

/// Marks a request that must outlive an application change: the retry queue neither purges it nor
/// re-addresses it. Today only the unregister of the previous application sets it.
@property (nonatomic, assign) BOOL survivesApplicationChange;

@end

NS_ASSUME_NONNULL_END
