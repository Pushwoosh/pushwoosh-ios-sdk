//
//  PWInboxStorage.m
//  Pushwoosh
//
//  Created by Victor Eysner on 26/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInboxStorage.h"
#import "PWInboxMerge.h"
#import "PWInboxMessageInternal+Status.h"
#import "PWUtils.h"

@interface PWInboxStorage ()

@property (nonatomic) NSMutableDictionary<NSString *, PWInboxMessageInternal *> *pushNotificationMessages;
@property (nonatomic) NSMutableDictionary<NSString *, PWInboxMessageInternal *> *serviceMessages;
@property (nonatomic) NSMutableDictionary<NSString *, PWInboxMessageInternal *> *allMessages;

@property (nonatomic) PWInboxMerge *mergeController;

@end

@implementation PWInboxStorage

- (instancetype)init {
    if (self = [super init]) {
        _mergeController = [PWInboxMerge new];
        [self loadMessages];
        [self updateAllMessages];
    }
    return self;
}

- (NSInteger)count {
    return _allMessages.count;
}

- (NSDictionary<NSString *, PWInboxMessageInternal *> *)updateAllMessages {
    NSMutableDictionary<NSString *, PWInboxMessageInternal *> *allMessages = [NSMutableDictionary new];
    //remove notification messages
    [_pushNotificationMessages removeObjectsForKeys:_serviceMessages.allKeys];
    
    //update messages
    [allMessages addEntriesFromDictionary:_serviceMessages];
    [allMessages addEntriesFromDictionary:_pushNotificationMessages];
    _allMessages = allMessages;
    return allMessages;
}

- (void)addInboxMessageFromPushNotification:(PWInboxMessageInternal *)message {
    [_pushNotificationMessages setValue:message forKey:message.code];
    [self updateAllMessages];
    [self saveMessages];
}

- (void)updateInboxMessagesFromService:(NSDictionary<NSString *, PWInboxMessageInternal *> *)messages
                         completion:(void (^)(NSArray<PWInboxMessageInternal *> *needUpdateStatusMessages,
                                              NSArray<NSString *> *messagesDeleted,
                                              NSArray<PWInboxMessageInternal *> *messagesAdded,
                                              NSArray<PWInboxMessageInternal *> *messagesUpdated))completion {
    NSMutableArray<NSString *> *messagesDeleted = [_serviceMessages.allKeys mutableCopy];
    NSMutableArray<NSString *> *messageKeysAdded = [messages.allKeys mutableCopy];
    
    [messagesDeleted removeObjectsInArray:messages.allKeys];
    [_serviceMessages removeObjectsForKeys:messagesDeleted];
    
    [messageKeysAdded removeObjectsInArray:_allMessages.allKeys];
    PWInboxMessageInternal *nullMessage = [PWInboxMessageInternal new];
    NSMutableArray<PWInboxMessageInternal *> *messagesAdded = [[messages objectsForKeys:messageKeysAdded notFoundMarker:nullMessage] mutableCopy];
    [messagesAdded removeObject:nullMessage];
    
    [self addInboxMessagesDeleted:messagesDeleted
                    messagesAdded:messagesAdded
                      fromService:messages
                       completion:completion];
}

- (void)addInboxMessagesDeleted:(NSArray<NSString *> *)messagesDeleted
                  messagesAdded:(NSArray<PWInboxMessageInternal *> *)messagesAdded
                    fromService:(NSDictionary<NSString *, PWInboxMessageInternal *> *)messages
                         completion:(void (^)(NSArray<PWInboxMessageInternal *> *needUpdateStatusMessages,
                                              NSArray<NSString *> *messagesDeleted,
                                              NSArray<PWInboxMessageInternal *> *messagesAdded,
                                              NSArray<PWInboxMessageInternal *> *messagesUpdated))completion {
    __weak typeof(self) wself = self;
    [_mergeController mergeServiceMessages:messages
                                andStorage:self
                                completion:^(NSArray<PWInboxMessageInternal *> *needUpdateStatusMessages,
                                             NSArray<PWInboxMessageInternal *> *messagesUpdated) {
                                    [wself.serviceMessages addEntriesFromDictionary:messages];
                                    [wself updateAllMessages];
                                    [wself saveMessages];
                                    if (completion) {
                                        completion(needUpdateStatusMessages, messagesDeleted, messagesAdded, messagesUpdated);
                                    }
                                }];

}

- (NSArray<PWInboxMessageInternal *> *)updateStatus:(PWInboxMessageStatus)status withInboxMessageCodes:(NSArray<NSString *> *)codes {
    NSArray<PWInboxMessageInternal *> *messages = [self messagesForCodes:codes];
    NSMutableArray<PWInboxMessageInternal *> *updatedMessages = [NSMutableArray new];
    for (PWInboxMessageInternal *message in messages) {
        if ([message updateStatus:status]) {
            [updatedMessages addObject:message];
        }
    }
    [self saveMessages];
    return updatedMessages;
}

- (void)updateInboxMessage:(PWInboxMessageInternal *)message {
    [_serviceMessages setObject:message forKey:message.code];
    [self updateAllMessages];
    [self saveMessages];
}

- (NSArray<PWInboxMessageInternal *> *)getAllMessages {
    return [self sortMessagesWitoutDeleted:_allMessages.allValues];
}

- (PWInboxMessageInternal *)messageForCode:(NSString *)code {
    return [_allMessages objectForKey:code];
}

- (NSArray<PWInboxMessageInternal *> *)messagesForCodes:(NSArray<NSString *> *)codes {
    PWInboxMessageInternal *notFoundMarker = [PWInboxMessageInternal new];
    NSMutableArray<PWInboxMessageInternal *> *list = [[_allMessages objectsForKeys:codes notFoundMarker:notFoundMarker] mutableCopy];
    [list removeObject:notFoundMarker];
    return [self sortMessagesWitoutDeleted:list];
}

- (void)getMessages:(NSString *)lastMessageCode limit:(NSInteger)limit completion:(void (^)(NSArray<PWInboxMessageInternal *> *messages, NSError *error))completion {
    NSArray<PWInboxMessageInternal *> *allMessages = [_allMessages.allValues copy];
    PWInboxMessageInternal *message = nil;
    if (lastMessageCode) {
        message = [_allMessages objectForKey:lastMessageCode];
    } else {
        message = _allMessages.allValues.firstObject;
    }
    if (!message && completion) {
        completion(nil, nil);
        return;
    }
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<PWInboxMessageInternal *> *sortMessages = [self sortMessagesWitoutDeleted:allMessages];
        NSInteger index = [sortMessages indexOfObject:message];
        NSInteger count = MIN(limit, sortMessages.count - index);
        NSArray<PWInboxMessageInternal *> *result = [sortMessages subarrayWithRange:NSMakeRange(index, count)];
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(result, nil);
        });
    });
}

#pragma mark -

- (NSArray<PWInboxMessageInternal *> *)sortMessagesWitoutDeleted:(NSArray<PWInboxMessageInternal *> *)allMessages {
    NSArray *messages = [allMessages filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PWInboxMessageInternal * _Nullable evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
        if ([evaluatedObject deleted] || evaluatedObject.isExpired) {
            return NO;
        } else {
            return YES;
        }
    }]];
    messages = [messages sortedArrayUsingComparator:^NSComparisonResult(PWInboxMessageInternal * _Nonnull obj1, PWInboxMessageInternal * _Nonnull obj2) {
        NSComparisonResult result = [obj2.sendDate compare:obj1.sendDate];
        if (result == NSOrderedSame) {
            
            result = [obj2.sortOrder compare:obj1.sortOrder];
            if (result == NSOrderedSame) {
                return [obj2.code compare:obj1.code];
            } else {
                return result;
            }
            
        } else {
            return result;
        }
    }];
    return messages;
}

- (BOOL)removeExpiredMessageInDictionary:(NSMutableDictionary<NSString *, PWInboxMessageInternal *> *)dictionaty {
    NSMutableArray<NSString *> *removeKeys = [NSMutableArray new];
    for (NSString *key in dictionaty.allKeys) {
        PWInboxMessageInternal *message = dictionaty[key];
        if (message.isExpired) {
            [removeKeys addObject:key];
        }
    }
    [dictionaty removeObjectsForKeys:removeKeys];
    return removeKeys.count;
}

- (void)reset {
    _serviceMessages = [NSMutableDictionary new];
    _pushNotificationMessages = [NSMutableDictionary new];
    [self updateAllMessages];
    [self saveMessages];
}

#pragma mark -

- (void)loadMessages {
    _serviceMessages = [self loadWithFileName:@"PWInbox.serviceMessages"] ?: [NSMutableDictionary new];
    _pushNotificationMessages = [self loadWithFileName:@"PWInbox.pushNotificationMessages"] ?: [NSMutableDictionary new];
    
    if ([self removeExpiredMessageInDictionary:_serviceMessages] || [self removeExpiredMessageInDictionary:_pushNotificationMessages]) {
        [self saveMessages];
    }
}

- (void)saveMessages {
    [self save:_serviceMessages forFileName:@"PWInbox.serviceMessages"];
    [self save:_pushNotificationMessages forFileName:@"PWInbox.pushNotificationMessages"];
}

- (NSString *)pathForFileName:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = paths[0];
    NSString *path = [NSString stringWithFormat:@"%@/%@", documentsDirectory, fileName];
    
    return path;
}

- (BOOL)save:(NSMutableDictionary<NSString *, PWInboxMessageInternal *> *)dictionary forFileName:(NSString *)fileName {
    NSString *path = [self pathForFileName:fileName];
    
    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"11.0"]) {
        NSError *error = nil;
                
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:dictionary requiringSecureCoding:YES error:&error];
        return [data writeToFile:path options:NSDataWritingAtomic error:&error];
    } else {
        return [NSKeyedArchiver archiveRootObject:dictionary toFile:path];
    }
}

- (NSMutableDictionary<NSString *, PWInboxMessageInternal *> *)loadWithFileName:(NSString *)fileName {
    NSString *path = [self pathForFileName:fileName];
    
    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"11.0"]) {
        NSURL *url = [NSURL fileURLWithPath:path];
        NSData *data = [NSData dataWithContentsOfURL:url];
        
        if (data == nil) {
            return nil;
        }
        
        NSError *error = nil;
        NSMutableDictionary *dict = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSMutableDictionary class] fromData:data error:&error];
        if (error != nil) {
            PWLogError(@"Deserialization failed: %@", error.localizedDescription);
            return nil;
        } else {
            return dict;
        }
    } else {
        return [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    }
}

@end
