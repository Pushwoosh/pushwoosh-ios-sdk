//
//  PWInboxMessageInternal.h
//  Pushwoosh
//
//  Created by Victor Eysner on 19/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInbox.h"

typedef NS_ENUM(NSInteger, PWInboxMessageStatus) {
    PWInboxMessageStatusCreated = 0,
    PWInboxMessageStatusDelivered = 1,
    PWInboxMessageStatusRead = 2,
    PWInboxMessageStatusAction = 3,
    PWInboxMessageStatusDeleted = 4,
    PWInboxMessageStatusDeletedService = 5
};

@interface PWInboxMessageInternal : NSObject<PWInboxMessageProtocol, NSSecureCoding>

//protocol
@property (readonly, nonatomic) NSString *code;
@property (readonly, nonatomic) NSString *title;
@property (readonly, nonatomic) NSString *message;
@property (readonly, nonatomic) NSDate *sendDate;
@property (readonly, nonatomic) NSString *imageUrl;
@property (readonly, nonatomic) PWInboxMessageType type;
@property (readonly, nonatomic) BOOL isRead;
@property (readonly, nonatomic) BOOL isActionPerformed;
@property (readonly, nonatomic) BOOL deleted;
@property (readonly, nonatomic) NSString *attachmentUrl;

//internal
@property (readonly, nonatomic) BOOL isExpired;
@property (readonly, nonatomic) NSString *sortOrder; //sortOrder && id for inbox api pushwoosh
@property (readonly, nonatomic) NSString *inboxHash;
@property (readonly, nonatomic) NSDate *expirationDate;
@property (readonly, nonatomic) NSDictionary *actionParams;
@property (readonly, nonatomic) PWInboxMessageStatus status;
@property (readonly, nonatomic) BOOL canUpdateStatus;
@property (readonly, nonatomic) BOOL isFromNotification;

+ (instancetype)messageWithDictionary:(NSDictionary *)dictionary;
+ (BOOL)validateDictionary:(NSDictionary *)dictionary;

#pragma mark - PushNotification methods

+ (instancetype)messageWithPushNotification:(NSDictionary *)userInfo;
+ (BOOL)isInboxPushNotification:(NSDictionary *)userInfo;
+ (BOOL)isFromNotification:(PWInboxMessageInternal *)message;

@end
