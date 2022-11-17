//
//  PWInboxService.h
//  Pushwoosh
//
//  Created by Victor Eysner on 26/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PWInboxMessageInternal;
@interface PWInboxService : NSObject
- (void)reset;

- (BOOL)canReloadData;

- (void)getAllMessagesWithCompletion:(void (^)(NSDictionary<NSString *, PWInboxMessageInternal *> *messages, NSError *error))completion;
- (void)getMessages:(NSString *)lastMessageCode limit:(NSInteger)limit completion:(void (^)(NSDictionary<NSString *, PWInboxMessageInternal *> *messages, NSError *error))completion;

- (void)sendStatusInDiffMessages:(NSArray<PWInboxMessageInternal *> *)messages;
- (void)readMessages:(NSArray<PWInboxMessageInternal *> *)messages;
- (void)actionMessages:(NSArray<PWInboxMessageInternal *> *)messages;
- (void)deleteMessages:(NSArray<PWInboxMessageInternal *> *)messages;

@end
