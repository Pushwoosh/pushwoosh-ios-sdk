//
//  PWInbox.m
//  Pushwoosh
//
//  Created by Victor Eysner on 18/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInbox.h"
#import "PWInboxStorage.h"
#import "PWInboxService.h"
#import "PWInbox+Internal.h"
#import "PWInboxMessagesRequest.h"
#import "PWInboxUpdateStatusRequest.h"
#import "PWNetworkModule.h"
#import "PWInboxMessageInternal+Status.h"
#import "Pushwoosh+Internal.h"

NSString * const PWInboxMessagesDidUpdateNotification = @"PWInboxMessagesDidUpdateNotification.com.pushwoosh.inbox";
NSString * const PWInboxMessagesDidReceiveInPushNotification = @"PWInboxMessagesDidReceiveInPushNotification.com.pushwoosh.inbox";

typedef void (^PWMessageCompletion)(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error);

@interface PWInbox ()

@property (nonatomic) PWInboxStorage *storage;
@property (nonatomic) PWInboxService *service;
@property (nonatomic) PWRequestManager *requestManager;

@end

@implementation PWInbox

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self dependencySetup];
        // Add observer to listen update inbox messages when app appeared from background
        // At the moment of UIApplicationWillEnterForegroundNotification socket may not be ready yet and request may fail
        // So we use UIApplicationDidBecomeActiveNotification
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wentForeground) name:
#if TARGET_OS_IOS || TARGET_OS_WATCH
         UIApplicationDidBecomeActiveNotification
#elif TARGET_OS_OSX
         NSApplicationDidBecomeActiveNotification
#endif
        object:nil];
    }
    return self;
}

- (void)dependencySetup {
    [[PWNetworkModule module] inject:self];
    _storage = [PWInboxStorage new];
    _service = [PWInboxService new];
}

- (void)wentForeground {
    [self loadInboxMessages];
}

- (void)loadInboxMessages {
    [PWInbox loadMessagesWithCompletion:^(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error) {
        if (!error && messages.count) {
            [PWInbox sendMessageFromPushNotification:@[messages.lastObject]];
        } else if (error) {
            PWLogError(@"Load inbox message error: %@", error.localizedDescription);
        }
    }];
}

#pragma mark - Notifications Methods

+ (void)sendMessageFromPushNotification:(NSArray *)messages {
    [self sendNotificationWithMessagesAdded:messages messagesDeleted:nil messagesUpdated:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:PWInboxMessagesDidReceiveInPushNotification
                                                        object:self
                                                      userInfo:@{
                                                                 @"messagesAdded" : messages ?: @[]
                                                                 }];
}

+ (void)sendNotificationWithMessagesAdded:(NSArray *)messagesAdded messagesDeleted:(NSArray *)messagesDeleted messagesUpdated:(NSArray *)messagesUpdated {
    if (messagesAdded.count || messagesUpdated.count || messagesDeleted.count) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PWInboxMessagesDidUpdateNotification
                                                            object:self
                                                          userInfo:@{@"messagesAdded" : messagesAdded ?: @[],
                                                                     @"messagesDeleted" : messagesDeleted ?: @[],
                                                                     @"messagesUpdated" : messagesUpdated ?: @[]
                                                                     }];
    }
}

#pragma mark - dispath public methods

- (void)getMessagesWithCompletion:(PWMessageCompletion)completion {
    [self getMessagesWithReloadingCondition:^BOOL{
        return [_service canReloadData];
    } completion:completion];
}

- (void)getMessagesWithReloadingCondition:(BOOL(^)())conditionBlock completion:(PWMessageCompletion)completion {
    if (!completion) {
        return;
    }
    
    if (conditionBlock()) {
        __weak typeof(self) wself = self;
        [_service getAllMessagesWithCompletion:^(NSDictionary<NSString *,PWInboxMessageInternal *> *serviceMessages, NSError *error) {
            if (error) {
                NSArray<PWInboxMessageInternal *> *messages = [wself.storage getAllMessages];
                completion(messages, error);
            } else {
                [wself.storage updateInboxMessagesFromService:serviceMessages
                                                   completion:^(NSArray<PWInboxMessageInternal *> *needUpdateStatusMessages,
                                                                NSArray<NSString *> *messagesDeleted,
                                                                NSArray<PWInboxMessageInternal *> *messagesAdded,
                                                                NSArray<PWInboxMessageInternal *> *messagesUpdated) {
                                                       [wself.class sendNotificationWithMessagesAdded:messagesAdded
                                                                                      messagesDeleted:messagesDeleted
                                                                                      messagesUpdated:messagesUpdated];
                                                       [wself.service sendStatusInDiffMessages:needUpdateStatusMessages];
                                                       NSArray<PWInboxMessageInternal *> *messages = [wself.storage getAllMessages];
                                                       completion(messages, error);
                                                   }];
            }
        }];
    } else {
        NSArray<PWInboxMessageInternal *> *messages = [_storage getAllMessages];
        completion(messages, nil);
    }
}

#pragma mark - internal api

+ (void)resetApplication {
    [[PWInbox sharedInstance].storage reset];
    [[PWInbox sharedInstance].service reset];
}

+ (BOOL)isInboxPushNotification:(NSDictionary *)userInfo {
    return [PWInboxMessageInternal isInboxPushNotification:userInfo];
}

+ (void)addInboxMessageFromPushNotification:(NSDictionary *)userInfo {
    PWInboxMessageInternal *message = [PWInboxMessageInternal messageWithPushNotification:userInfo];
    
    if (message) {
        if (message.message) {
            [[PWInbox sharedInstance].storage addInboxMessageFromPushNotification:message];
            [self sendMessageFromPushNotification:@[message]];
        } else { //silent push
            [[PWInbox sharedInstance].service reset]; //reset last update time
            [PWInbox loadMessagesWithCompletion:^(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error) {
                if (!error && messages.count) {
                    PWInboxMessageInternal *silentMessage = nil;
                    
                    for (PWInboxMessageInternal *serviceMessage in messages) {
                        if ([message.code isEqualToString:serviceMessage.code]) {
                            silentMessage = serviceMessage;
                            break;
                        }
                    }
                    
                    if (silentMessage) {
                        [self sendMessageFromPushNotification:@[silentMessage]];
                    }
                }
            }];
        }
    }
}

+ (void)actionInboxMessageFromPushNotification:(NSDictionary *)userInfo {
    PWInboxMessageInternal *message = [PWInboxMessageInternal messageWithPushNotification:userInfo];
    if (message.code) {
        NSArray<PWInboxMessageInternal *> *messages = [[PWInbox sharedInstance].storage updateStatus:PWInboxMessageStatusAction withInboxMessageCodes:@[message.code]];
        [[PWInbox sharedInstance].service actionMessages:messages];
        [self sendMessageFromPushNotification:@[message]];
    }
}

#pragma mark - stat methods

+ (void)sendStaticMessage:(NSArray<PWInboxMessageInternal *> *)messages {
    for (PWInboxMessageInternal *message in messages) {
        if (message.canUpdateStatus) {
            [[Pushwoosh sharedInstance].dataManager sendStatsForPush:message.actionParams];
        }
    }
}

#pragma mark - public methods

+ (void)messagesWithNoActionPerformedCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion {
    [[PWInbox sharedInstance] getMessagesWithReloadingCondition:^BOOL{
        return [PWInbox sharedInstance].storage.count == 0;
    } completion:^(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error) {
        if (completion) {
            NSInteger count = 0;
            for (PWInboxMessageInternal *message in messages) {
                if (!message.isActionPerformed) {
                    count++;
                }
            }
            completion(count, error);
        }
    }];
}

+ (void)unreadMessagesCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion {
    [[PWInbox sharedInstance] getMessagesWithReloadingCondition:^BOOL{
        return [PWInbox sharedInstance].storage.count == 0;
    } completion:^(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error) {
        if (completion) {
            NSInteger count = 0;
            for (PWInboxMessageInternal *message in messages) {
                if (!message.isRead) {
                    count++;
                }
            }
            completion(count, error);
        }
    }];
}

+ (void)messagesCountWithCompletion:(void (^)(NSInteger count, NSError *error))completion {
    [[PWInbox sharedInstance] getMessagesWithCompletion:^(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error) {
        if (completion) {
            completion(messages.count, error);
        }
    }];
}

+ (void)loadMessagesWithCompletion:(PWMessageCompletion)completion {
    [[PWInbox sharedInstance] getMessagesWithCompletion:completion];
}

+ (void)readMessagesWithCodes:(NSArray<NSString *> *)codes {
    NSArray<PWInboxMessageInternal *> *messages = [[PWInbox sharedInstance].storage updateStatus:PWInboxMessageStatusRead withInboxMessageCodes:codes];
    [[PWInbox sharedInstance].service readMessages:messages];
    [PWInbox sendNotificationWithMessagesAdded:nil messagesDeleted:nil messagesUpdated:messages];
}

+ (void)deleteMessagesWithCodes:(NSArray<NSString *> *)codes {
    NSArray<PWInboxMessageInternal *> *messages = [[PWInbox sharedInstance].storage updateStatus:PWInboxMessageStatusDeleted withInboxMessageCodes:codes];
    [[PWInbox sharedInstance].service deleteMessages:messages];
    [PWInbox sendNotificationWithMessagesAdded:nil messagesDeleted:messages messagesUpdated:nil];
}

+ (void)performActionForMessageWithCode:(NSString *)code {
    NSArray<PWInboxMessageInternal *> *updateMessages = [[PWInbox sharedInstance].storage updateStatus:PWInboxMessageStatusAction withInboxMessageCodes:@[code]];
    PWInboxMessageInternal *message = [[PWInbox sharedInstance].storage messageForCode:code];
    [[PWInbox sharedInstance].service actionMessages:@[message]];
    [PWInbox sendStaticMessage:updateMessages];
    
    [[Pushwoosh sharedInstance].pushNotificationManager processActionUserInfo:message.actionParams];
    
    [PWInbox sendNotificationWithMessagesAdded:nil messagesDeleted:nil messagesUpdated:updateMessages];
}

+ (id<NSObject>)addObserverForDidReceiveInPushNotificationCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messagesAdded))completion {
    id <NSObject> observer = [[NSNotificationCenter defaultCenter] addObserverForName:PWInboxMessagesDidReceiveInPushNotification
                                                                               object:nil
                                                                                queue:[NSOperationQueue mainQueue]
                                                                           usingBlock:^(NSNotification * _Nonnull note) {
                                                                               if (completion) {
                                                                                   completion(note.userInfo[@"messagesAdded"]);
                                                                               }
                                                                           }];
    return observer;
}

+ (id<NSObject>)addObserverForUpdateInboxMessagesCompletion:(void (^)(NSArray<NSObject<PWInboxMessageProtocol> *> *messagesDeleted,
                                                                      NSArray<NSObject<PWInboxMessageProtocol> *> *messagesAdded,
                                                                      NSArray<NSObject<PWInboxMessageProtocol> *> *messagesUpdated))completion {
    id <NSObject> observer = [[NSNotificationCenter defaultCenter] addObserverForName:PWInboxMessagesDidUpdateNotification
                                                                                   object:nil
                                                                                    queue:[NSOperationQueue mainQueue]
                                                                               usingBlock:^(NSNotification * _Nonnull note) {
                                                                                    if (completion) {
                                                                                        completion(note.userInfo[@"messagesDeleted"],
                                                                                                   note.userInfo[@"messagesAdded"],
                                                                                                   note.userInfo[@"messagesUpdated"]);
                                                                                    }
                                                                           }];
    return observer;
}


+ (id<NSObject>)addObserverForUnreadMessagesCountUsingBlock:(void (^)(NSUInteger count))block {
    id <NSObject> observer = [[NSNotificationCenter defaultCenter] addObserverForName:PWInboxMessagesDidUpdateNotification
                                                                               object:nil
                                                                                queue:[NSOperationQueue mainQueue]
                                                                           usingBlock:^(NSNotification * _Nonnull note) {
                                                                                if (block) {
                                                                                    [self unreadMessagesCountWithCompletion:^(NSInteger count, NSError *error) {
                                                                                        if (!error) {
                                                                                            block(count);
                                                                                        }
                                                                                    }];
                                                                                }
    }];
    return observer;
}

+ (id<NSObject>)addObserverForNoActionPerformedMessagesCountUsingBlock:(void (^)(NSUInteger count))block {
    id <NSObject> observer = [[NSNotificationCenter defaultCenter] addObserverForName:PWInboxMessagesDidUpdateNotification
                                                                               object:nil
                                                                                queue:[NSOperationQueue mainQueue]
                                                                           usingBlock:^(NSNotification * _Nonnull note) {
                                                                                if (block) {
                                                                                    [self messagesWithNoActionPerformedCountWithCompletion:^(NSInteger count, NSError *error) {
                                                                                        if (!error) {
                                                                                            block(count);
                                                                                        }
                                                                                    }];
                                                                                }
    }];
    return observer;
}

+ (void)removeObserver:(id<NSObject> )observer {
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
}

+ (void)updateInboxForNewUserId:(void (^)(NSUInteger messagesCount))completion {
    [PWInbox loadMessagesWithCompletion:^(NSArray<NSObject<PWInboxMessageProtocol> *> *messages, NSError *error) {
        if (!error || messages != nil)
            completion(messages.count);
        else
            PWLogError(@"Messages array is equail nil or something went wrong with error: %@", error.localizedDescription);
    }];
    
}

@end
