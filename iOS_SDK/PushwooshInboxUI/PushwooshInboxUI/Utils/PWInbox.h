//
//  PWInbox.h
//  Pushwoosh
//
//  Created by Pushwoosh on 18/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString * const PWInboxMessagesDidUpdateNotification;
FOUNDATION_EXPORT NSString * const PWInboxMessagesDidReceiveInPushNotification;

typedef NS_ENUM(NSInteger, PWInboxMessageType) {
    PWInboxMessageTypePlain = 0,
    PWInboxMessageTypeRichmedia = 1,
    PWInboxMessageTypeURL = 2,
    PWInboxMessageTypeDeeplink = 3
};

@protocol PWInboxMessageProtocol <NSObject>

@required

@property (readonly, nonatomic) NSString *code;
@property (readonly, nonatomic) NSString *title;
@property (readonly, nonatomic) NSString *imageUrl;
@property (readonly, nonatomic) NSString *message;
@property (readonly, nonatomic) NSDate *sendDate;
@property (readonly, nonatomic) PWInboxMessageType type;
@property (readonly, nonatomic) BOOL isRead;
@property (readonly, nonatomic) BOOL isActionPerformed;
@property (readonly, nonatomic) NSString *attachmentUrl;
@property (readonly, nonatomic) NSDictionary *actionParams;

@end

@interface PWInbox : NSObject

- (instancetype)init NS_UNAVAILABLE;

+ (void)messagesWithNoActionPerformedCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion;
+ (void)unreadMessagesCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion;
+ (void)messagesCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion;
+ (void)loadMessagesWithCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error))completion;

+ (void)performActionForMessageWithCode:(NSString *)code;
+ (void)deleteMessagesWithCodes:(NSArray<NSString *> *)codes;
+ (void)readMessagesWithCodes:(NSArray<NSString *> *)codes;

+ (id<NSObject>)addObserverForDidReceiveInPushNotificationCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messagesAdded))completion;
+ (id<NSObject>)addObserverForUpdateInboxMessagesCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messagesDeleted,
                                                                      NSArray<NSObject<PWInboxMessageProtocol> *> *messagesAdded,
                                                                      NSArray<NSObject<PWInboxMessageProtocol> *> *messagesUpdated))completion;
+ (void)removeObserver:(id<NSObject>)observer;

@end
