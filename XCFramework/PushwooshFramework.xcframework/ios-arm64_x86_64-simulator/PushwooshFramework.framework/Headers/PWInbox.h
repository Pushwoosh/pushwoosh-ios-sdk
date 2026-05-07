//
//  PWInbox.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2017
//

#import <Foundation/Foundation.h>
#import <PushwooshCore/PushwooshLog.h>
#import <PushwooshCore/PWInboxTypes.h>
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
+ (void)messagesWithNoActionPerformedCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion;

/**
 Get the number of the unread PWInboxMessageProtocol
 
 @param completion - if successful, return the number of the unread InboxMessages. Otherwise, return error
 */
+ (void)unreadMessagesCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion;

/**
 Get the total number of the PWInboxMessageProtocol
 
 @param completion - if successful, return the total number of the InboxMessages. Otherwise, return error
 */
+ (void)messagesCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion;

/**
 Get the collection of the PWInboxMessageProtocol that the user received
 
 @param completion - if successful, return the collection of the InboxMessages. Otherwise, return error
 */
+ (void)loadMessagesWithCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error))completion;

/**
 Call this method to mark the list of InboxMessageProtocol as read
 
 @param codes of the inboxMessages
 */
+ (void)readMessagesWithCodes:(NSArray<NSString *> *)codes;

/**
 Marks every currently-stored unread inbox message as read in a single call.
 Convenience over filtering the result of `loadMessagesWithCompletion:` and
 calling `readMessagesWithCodes:` yourself.
 */
+ (void)markAllMessagesAsRead;

/**
 Returns a single inbox message identified by its code without loading the
 entire feed. Reads from the local `PWInboxStorage` cache. Returns `nil` if
 the message has not been seen yet, has been deleted, or has expired.

 @param code of the inboxMessage
 */
+ (nullable id<PWInboxMessageProtocol>)messageForCode:(NSString *)code;

/**
 Call this method, when the user clicks on the InboxMessageProtocol and the message’s action is performed

 @param code of the inboxMessage that the user tapped
 */
+ (void)performActionForMessageWithCode:(NSString *)code;

/**
 Call this method, when the user deletes the list of InboxMessageProtocol manually

 @param codes of the list of InboxMessageProtocol.code that the user deleted
 */
+ (void)deleteMessagesWithCodes:(NSArray<NSString *> *)codes;

/**
 Deletes every read inbox message in one call. Useful for "Clear read"
 affordances. Unread and pinned-but-unread messages are preserved.
 */
+ (void)deleteAllReadMessages;

/**
 Subscribe for messages arriving with push notifications. @warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications
 
 @param completion - return the collection of the InboxMessages.
 */
+ (id<NSObject>)addObserverForDidReceiveInPushNotificationCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messagesAdded))completion;

/**
 Subscribe for messages arriving when a message is deleted, added, or updated. @warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications
 
 @param completion - return the collection of the InboxMessages.
 */
+ (id<NSObject>)addObserverForUpdateInboxMessagesCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messagesDeleted,
                                                                      NSArray<NSObject<PWInboxMessageProtocol> *> *messagesAdded,
                                                                      NSArray<NSObject<PWInboxMessageProtocol> *> *messagesUpdated))completion;

/**
Subscribe for unread messages count changes. @warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications

@param block - return the count of unread messages.
*/
+ (id<NSObject>)addObserverForUnreadMessagesCountUsingBlock:(void (^)(NSUInteger count))block;

/**
Subscribe for messages with no action performed count changes. @warning You need to unsubscribe by calling the removeObserver method, if you don't want to receive notifications

@param block - return the count of unread messages.
*/
+ (id<NSObject>)addObserverForNoActionPerformedMessagesCountUsingBlock:(void (^)(NSUInteger count))block;

/**
 Unsubscribes from notifications
 
 @param observer - Unsubscribes observer
 */
+ (void)removeObserver:(id<NSObject>)observer;

/**
 updates observers
 */
+ (void)updateInboxForNewUserId:(void (^)(NSUInteger messagesCount))completion;
@end
