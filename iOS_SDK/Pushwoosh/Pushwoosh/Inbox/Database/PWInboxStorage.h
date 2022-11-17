//
//  PWInboxStorage.h
//  Pushwoosh
//
//  Created by Victor Eysner on 26/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWInboxMessageInternal.h"

@interface PWInboxStorage : NSObject

- (void)reset;
- (NSInteger)count;
- (void)updateInboxMessagesFromService:(NSDictionary<NSString *, PWInboxMessageInternal *> *)messages
                            completion:(void (^)(NSArray<PWInboxMessageInternal *> *needUpdateStatusMessages,
                                                 NSArray<NSString *> *messagesDeleted,
                                                 NSArray<PWInboxMessageInternal *> *messagesAdded,
                                                 NSArray<PWInboxMessageInternal *> *messagesUpdated))completion;

- (void)addInboxMessageFromPushNotification:(PWInboxMessageInternal *)message;
- (void)updateInboxMessage:(PWInboxMessageInternal *)message;
- (NSArray<PWInboxMessageInternal *> *)updateStatus:(PWInboxMessageStatus)status withInboxMessageCodes:(NSArray<NSString *> *)codes;

- (NSArray<PWInboxMessageInternal *> *)getAllMessages;
- (void)getMessages:(NSString *)lastMessageCode limit:(NSInteger)limit completion:(void (^)(NSArray<PWInboxMessageInternal *> *messages, NSError *error))completion;
- (PWInboxMessageInternal *)messageForCode:(NSString *)code;
- (NSArray<PWInboxMessageInternal *> *)messagesForCodes:(NSArray<NSString *> *)codes;

@end
