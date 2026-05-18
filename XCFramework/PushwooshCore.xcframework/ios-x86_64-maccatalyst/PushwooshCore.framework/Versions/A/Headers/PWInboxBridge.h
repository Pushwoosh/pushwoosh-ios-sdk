//
//  PWInboxBridge.h
//  PushwooshCore
//
//  Created by André Kis on 20.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PWInboxMessageProtocol;

/// Bridge protocol exposing the inbox backend (PushwooshFramework's `PWInbox`)
/// to the optional UI module `PushwooshInboxKit` without a hard compile-time
/// dependency on `PushwooshFramework`.
///
/// Conforming class must route every mutation through the canonical
/// `PWInboxStorage` so the deleted/read flags survive across launches.
@protocol PWInboxBridge <NSObject>

/// Push-driven dispatch surface — used by PushwooshCore's notification path
/// to feed inbox-flagged push payloads into the storage layer in real time.
+ (BOOL)isInboxPushNotification:(NSDictionary *)userInfo;
+ (void)addInboxMessageFromPushNotification:(NSDictionary *)userInfo;
+ (void)actionInboxMessageFromPushNotification:(NSDictionary *)userInfo;
+ (void)resetApplication;
+ (void)updateInboxForNewUserId:(void (^)(NSUInteger messagesCount))completion;

/// Storage-aware UI surface — every method here is expected to go through
/// `PWInboxStorage` so that local mutations (deleted/read/action) are
/// persisted to disk and survive a process restart even if the corresponding
/// network request has not yet been acknowledged.
+ (void)loadMessagesWithCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error))completion;
+ (void)readMessagesWithCodes:(NSArray<NSString *> *)codes;
+ (void)deleteMessagesWithCodes:(NSArray<NSString *> *)codes;
+ (void)performActionForMessageWithCode:(NSString *)code;
+ (void)markAllMessagesAsRead;
+ (void)deleteAllReadMessages;

@end
