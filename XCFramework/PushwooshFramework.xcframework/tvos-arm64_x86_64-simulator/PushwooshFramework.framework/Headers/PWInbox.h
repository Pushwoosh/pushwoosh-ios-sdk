//
//  PWInbox.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWInboxTypes.h>
#import <PushwooshCore/PWInboxTabs.h>
#import <PushwooshCore/PWInboxBridge.h>

/**
 The notification arriving on the Inbox messages renewal
 */
FOUNDATION_EXPORT NSString * const PWInboxMessagesDidUpdateNotification;

/**
 The notification arriving when a push message is added to Inbox
 */
FOUNDATION_EXPORT NSString * const PWInboxMessagesDidReceiveInPushNotification;

/// Conforms to `PWInboxBridge` so optional Swift modules
/// (e.g. `PushwooshInboxKit`) can reach the storage-backed inbox API
/// through `PWManagerBridge.shared.inboxBridge as? PWInboxBridge.Type`.
/// Without the formal conformance the Swift cast returns `nil` at runtime
/// and every bridge call silently no-ops — mutations never reach disk.
@interface PWInbox : NSObject <PWInboxBridge>

- (instancetype)init NS_UNAVAILABLE;

/**
 Get the number of the PWInboxMessageProtocol with no action performed

 @param completion - if successful, return the number of the InboxMessages with no action performed. Otherwise, return error
 */
+ (void)messagesWithNoActionPerformedCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Get the number of the unread PWInboxMessageProtocol

 @param completion - if successful, return the number of the unread InboxMessages. Otherwise, return error
 */
+ (void)unreadMessagesCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Get the total number of the PWInboxMessageProtocol

 @param completion - if successful, return the total number of the InboxMessages. Otherwise, return error
 */
+ (void)messagesCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Get the collection of the PWInboxMessageProtocol that the user received

 @param completion - if successful, return the collection of the InboxMessages. Otherwise, return error
 */
+ (void)loadMessagesWithCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error))completion __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Returns the Control-Panel-configured Inbox tab list, served synchronously from memory.
 Safe to call on the main thread.

 The list is as fresh as the last completed `loadMessagesWithCompletion:` call or
 `PWInboxMessagesDidUpdateNotification`; there is no separate "tabs changed" event.
 `nil` means this app has no tabs configured and the inbox is a single feed.
 */
+ (PWInboxTabs * _Nullable)getTabs __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Call this method to mark the list of InboxMessageProtocol as read

 @param codes of the inboxMessages
 */
+ (void)readMessagesWithCodes:(NSArray<NSString *> *)codes __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Marks every currently-stored unread inbox message as read in a single call.
 Convenience over filtering the result of `loadMessagesWithCompletion:` and
 calling `readMessagesWithCodes:` yourself.
 */
+ (void)markAllMessagesAsRead __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Returns a single inbox message identified by its code without loading the
 entire feed. Reads from the local `PWInboxStorage` cache. Returns `nil` if
 the message has not been seen yet, has been deleted, or has expired.

 @param code of the inboxMessage
 */
+ (nullable id<PWInboxMessageProtocol>)messageForCode:(NSString *)code __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Call this method, when the user clicks on the InboxMessageProtocol and the message’s action is performed

 @param code of the inboxMessage that the user tapped
 */
+ (void)performActionForMessageWithCode:(NSString *)code __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Report that the user acted on a message, without running the message's own action.

 Use this when the UI has already taken the user somewhere — an inline button or a
 carousel slide carries its own URL and opens it itself. Calling
 `performActionForMessageWithCode:` there would additionally run the message-level
 action (`l` deep link, `rm` rich media), sending the user to a second, different
 destination. This method sends the open (status 3) and nothing else.

 @param code of the inboxMessage the user acted on
 */
+ (void)reportActionForMessageWithCode:(NSString *)code __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Call this method, when the user deletes the list of InboxMessageProtocol manually

 @param codes of the list of InboxMessageProtocol.code that the user deleted
 */
+ (void)deleteMessagesWithCodes:(NSArray<NSString *> *)codes __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Deletes every read inbox message in one call. Useful for "Clear read"
 affordances. Unread and pinned-but-unread messages are preserved.
 */
+ (void)deleteAllReadMessages __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Subscribe for messages arriving with push notifications. @warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications

 @param completion - return the collection of the InboxMessages.
 */
+ (id<NSObject>)addObserverForDidReceiveInPushNotificationCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messagesAdded))completion __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Subscribe for messages arriving when a message is deleted, added, or updated. @warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications

 @param completion - return the collection of the InboxMessages.
 */
+ (id<NSObject>)addObserverForUpdateInboxMessagesCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messagesDeleted,
                                                                      NSArray<NSObject<PWInboxMessageProtocol> *> *messagesAdded,
                                                                      NSArray<NSObject<PWInboxMessageProtocol> *> *messagesUpdated))completion __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
Subscribe for unread messages count changes. @warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications

@param block - return the count of unread messages.
*/
+ (id<NSObject>)addObserverForUnreadMessagesCountUsingBlock:(void (^)(NSUInteger count))block __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
Subscribe for messages with no action performed count changes. @warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications

@param block - return the count of unread messages.
*/
+ (id<NSObject>)addObserverForNoActionPerformedMessagesCountUsingBlock:(void (^)(NSUInteger count))block __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 Unsubscribes from notifications

 @param observer - Unsubscribes observer
 */
+ (void)removeObserver:(id<NSObject>)observer __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));

/**
 updates observers
 */
+ (void)updateInboxForNewUserId:(void (^)(NSUInteger messagesCount))completion __attribute__((deprecated("Since 7.3.0: Use Pushwoosh.inbox (Objective-C: [Pushwoosh inbox]) instead.")));
@end

/// Inbox API behind `Pushwoosh.inbox` (Objective-C: `[Pushwoosh inbox]`); same calls as the deprecated `PWInbox` methods.
@protocol PWInboxCenter <NSObject>

/// Counts the messages whose action has not been performed yet.
+ (void)messagesWithNoActionPerformedCountWithCompletion:(void (^_Null_unspecified)(NSInteger count, NSError *_Null_unspecified error))completion;

/// Counts the unread messages.
+ (void)unreadMessagesCountWithCompletion:(void (^_Null_unspecified)(NSInteger count, NSError *_Null_unspecified error))completion;

/// Counts all stored messages.
+ (void)messagesCountWithCompletion:(void (^_Null_unspecified)(NSInteger count, NSError *_Null_unspecified error))completion;

/// Loads the messages the user received: the local cache merged with the server feed.
+ (void)loadMessagesWithCompletion:(void (^_Null_unspecified)(NSArray<NSObject<PWInboxMessageProtocol> *> *_Nullable_result messages, NSError *_Null_unspecified error))completion;

/// The Control-Panel tab list from memory, as fresh as the last `loadMessagesWithCompletion:`; `nil` = no tabs, a single feed.
+ (PWInboxTabs * _Nullable)getTabs;

/// Marks the messages with these codes as read.
+ (void)readMessagesWithCodes:(NSArray<NSString *> *_Null_unspecified)codes;

/// Marks every stored unread message as read.
+ (void)markAllMessagesAsRead;

/// Returns a stored message by code without loading the feed; `nil` if it is unknown, deleted or expired.
+ (nullable id<PWInboxMessageProtocol>)messageForCode:(NSString *_Null_unspecified)code;

/// Runs the message action (deep link, rich media) and reports the open.
+ (void)performActionForMessageWithCode:(NSString *_Null_unspecified)code;

/// Reports the open without running the message action, for UI that already opened its own destination.
+ (void)reportActionForMessageWithCode:(NSString *_Null_unspecified)code;

/// Deletes the messages with these codes.
+ (void)deleteMessagesWithCodes:(NSArray<NSString *> *_Null_unspecified)codes;

/// Deletes every read message; unread ones stay.
+ (void)deleteAllReadMessages;

/// Subscribes to messages arriving with pushes; keep the token and pass it to `removeObserver:`.
+ (id<NSObject> _Null_unspecified)addObserverForDidReceiveInPushNotificationCompletion:(void (^_Null_unspecified)(NSArray<NSObject<PWInboxMessageProtocol> *> *_Null_unspecified messagesAdded))completion;

/// Subscribes to deleted, added and updated messages; keep the token and pass it to `removeObserver:`.
+ (id<NSObject> _Null_unspecified)addObserverForUpdateInboxMessagesCompletion:(void (^_Null_unspecified)(NSArray<NSObject<PWInboxMessageProtocol> *> *_Null_unspecified messagesDeleted,
                                                                                                     NSArray<NSObject<PWInboxMessageProtocol> *> *_Null_unspecified messagesAdded,
                                                                                                     NSArray<NSObject<PWInboxMessageProtocol> *> *_Null_unspecified messagesUpdated))completion NS_SWIFT_NAME(addObserver(forUpdateMessagesCompletion:));

/// Subscribes to unread count changes; keep the token and pass it to `removeObserver:`.
+ (id<NSObject> _Null_unspecified)addObserverForUnreadMessagesCountUsingBlock:(void (^_Null_unspecified)(NSUInteger count))block;

/// Subscribes to changes of the no-action-performed count; keep the token and pass it to `removeObserver:`.
+ (id<NSObject> _Null_unspecified)addObserverForNoActionPerformedMessagesCountUsingBlock:(void (^_Null_unspecified)(NSUInteger count))block;

/// Removes an observer returned by one of the `addObserver...` calls.
+ (void)removeObserver:(id<NSObject> _Null_unspecified)observer;

/// Re-syncs the inbox after the user changed and returns the new message count.
+ (void)updateInboxForNewUserId:(void (^_Null_unspecified)(NSUInteger messagesCount))completion;

@end

/// The class `Pushwoosh.inbox` returns; reach it through the accessor.
@interface PWInboxCenter : NSObject <PWInboxCenter>
@end
