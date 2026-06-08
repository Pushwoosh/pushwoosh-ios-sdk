//
//  PWReplayRequest.h
//  Pushwoosh
//
//  Created by André Kis
//

#import <PushwooshCore/PWRequest.h>

NS_ASSUME_NONNULL_BEGIN

/// A `PWRequest` reconstructed from a persisted `PWRetryEntry` so a queued retry can
/// be replayed through the normal `PWRequestManager` send path (gRPC or REST).
///
/// The frozen `methodName`/`requestDictionary`/`shouldWrapRequest`/`baseUrl` are
/// returned verbatim, and `cacheable` is forced to NO so a replay that fails again
/// is handled by the retry queue (via the transport completion) rather than
/// re-enqueued by the manager.
@interface PWReplayRequest : PWRequest

/// Designated initializer. `shouldWrapRequest`/`baseUrl` are the values frozen from
/// the original request so the replay is serialized and routed identically.
- (instancetype)initWithMethodName:(NSString *)methodName
                 requestDictionary:(NSDictionary *)requestDictionary
                 requestIdentifier:(NSString *)requestIdentifier
                 shouldWrapRequest:(BOOL)shouldWrapRequest
                           baseUrl:(nullable NSString *)baseUrl;

/// Convenience initializer defaulting to the standard transport
/// (`shouldWrapRequest = YES`, no `baseUrl` override).
- (instancetype)initWithMethodName:(NSString *)methodName
                 requestDictionary:(NSDictionary *)requestDictionary
                 requestIdentifier:(NSString *)requestIdentifier;

@end

NS_ASSUME_NONNULL_END
