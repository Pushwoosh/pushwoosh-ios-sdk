//
//  PWInboxService.m
//  Pushwoosh
//
//  Created by Victor Eysner on 26/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInboxService.h"
#import "PWInboxMessageInternal.h"
#import "PWInboxAllMessagesRequest.h"
#import "PWInboxMessagesRequest.h"
#import "PWInboxUpdateStatusRequest.h"
#import "PWNetworkModule.h"
#import "PWPreferences.h"
#import "PWInbox+Internal.h"

#import <UserNotifications/UserNotifications.h>

static NSInteger minimalTimeinterval = 10;

@interface PWIRequestBlock : NSObject

@property (nonatomic) NSString *requestUid;
@property (nonatomic, copy) void(^block)(PWRequest *request, NSError *error);

@end

@implementation PWIRequestBlock

+ (PWIRequestBlock *)requestBlock:(PWRequest *)request withBlock:(void (^)(PWRequest *request, NSError *error))completion {
    PWIRequestBlock *requestBlock = nil;
    
    if (request.uid == nil || completion == nil) {
        return requestBlock;
    } else {
        requestBlock = [PWIRequestBlock new];
        requestBlock.requestUid = request.uid;
        requestBlock.block = completion;
        return requestBlock;
    }
}

@end

@interface PWInboxService ()

@property (nonatomic) NSMutableArray<PWIRequestBlock *> *listBlock;
@property (nonatomic) NSMutableSet<NSString *> *listRequest;
@property (nonatomic) PWRequestManager *requestManager;
@property (nonatomic) NSDate *lastRequestTime;
@property (nonatomic) NSString *currentUserID;

@end

@implementation PWInboxService

- (instancetype)init {
    if (self = [super init]) {
        [self dependencySetup];
    }
    return self;
}

- (void)reset {
    [self dependencySetup];
    _lastRequestTime = nil;
}

- (void)dependencySetup {
    [[PWNetworkModule module] inject:self];
    _listBlock = [NSMutableArray new];
    _listRequest = [NSMutableSet new];
}

#pragma mark -

- (BOOL)canReloadData {
    if (_currentUserID && ![[PWPreferences preferences].userId isEqualToString:_currentUserID]) {
        [PWInbox resetApplication];
    }
    
    _currentUserID = [PWPreferences preferences].userId;
    
    if (_lastRequestTime && [[NSDate date] timeIntervalSinceDate:_lastRequestTime] < minimalTimeinterval) {
        return NO;
    } else {
        return YES;
    }
}

#pragma mark -

- (void)sendRequestBlock:(PWRequest *)request error:(NSError *)error {
    [_listRequest removeObject:request.uid];
    NSMutableArray<PWIRequestBlock *> *removeList = [NSMutableArray new];
    for (PWIRequestBlock *requestBlock in _listBlock) {
        if (requestBlock.requestUid) {
            [removeList addObject:requestBlock];
            requestBlock.block(request, error);
        }
    }
    [_listBlock removeObjectsInArray:removeList];
}

- (void)sendMessagesRequest:(PWRequest *)request withCompletion:(void (^)(PWRequest *request, NSError *error))completion {
    __weak typeof(self) wself = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        PWIRequestBlock *requestBlock = [PWIRequestBlock requestBlock:request withBlock:completion];
        if (requestBlock) {
            [wself.listBlock addObject:requestBlock];
            if (![wself.listRequest containsObject:request.uid]) {
                [wself.listRequest addObject:request.uid];
                [wself.requestManager sendRequest:request
                                       completion:^(NSError *error) {
                                           dispatch_async(dispatch_get_main_queue(), ^{
                                               [wself sendRequestBlock:request error:error];
                                           });
                                       }];
            }
        } else {
            [wself.requestManager sendRequest:request
                                   completion:^(NSError *error) {
                                       if (completion) {
                                           completion(request, error);
                                       }
                                   }];
        }
    });
}

- (void)getAllMessagesWithCompletion:(void (^)(NSDictionary<NSString *, PWInboxMessageInternal *> *messages, NSError *error))completion {
    __weak typeof(self) wself = self;
    PWInboxAllMessagesRequest *request = [[PWInboxAllMessagesRequest alloc] initWithLastRequestTime:_lastRequestTime];
    [self sendMessagesRequest:request
               withCompletion:^(PWRequest *request, NSError *error) {
                   if (!error) {
                       wself.lastRequestTime = [NSDate date];
                   }
                   if (completion) {
                       PWInboxAllMessagesRequest *requestMessage = (PWInboxAllMessagesRequest *)request;
                       completion(requestMessage.messages, error);
                   }
               }];
}

- (void)getMessages:(NSString *)lastMessageCode limit:(NSInteger)limit completion:(void (^)(NSDictionary<NSString *, PWInboxMessageInternal *> *messages, NSError *error))completion {
    __weak typeof(self) wself = self;
    PWInboxMessagesRequest *request = [[PWInboxMessagesRequest alloc] initWithLastInboxCode:lastMessageCode limit:limit lastRequestTime:_lastRequestTime];
    [_requestManager sendRequest:request
                      completion:^(NSError *error) {
                          if (!error) {
                              wself.lastRequestTime = [NSDate date];
                          }
                          if (completion) {
                              completion(request.messages, error);
                          }
                      }];
}

#pragma mark -

- (void)sendStatusInDiffMessages:(NSArray<PWInboxMessageInternal *> *)messages {
    for (PWInboxMessageInternal *message in messages) {
        if (message.canUpdateStatus && ![PWInboxMessageInternal isFromNotification:message]) {
            if (message.deleted) {
                [_requestManager sendRequest:[PWInboxUpdateStatusRequest deleteInboxMessage:message.sortOrder inboxHash:message.inboxHash] completion:nil];
            } else if (message.isActionPerformed) {
                [_requestManager sendRequest:[PWInboxUpdateStatusRequest actionInboxMessage:message.sortOrder inboxHash:message.inboxHash] completion:nil];
            } else if (message.isRead) {
                [_requestManager sendRequest:[PWInboxUpdateStatusRequest readInboxMessage:message.sortOrder inboxHash:message.inboxHash] completion:nil];
            }
        }
    }
}

- (void)readMessages:(NSArray<PWInboxMessageInternal *> *)messages {
    for (PWInboxMessageInternal *message in messages) {
        if (message.canUpdateStatus) {
            [_requestManager sendRequest:[PWInboxUpdateStatusRequest readInboxMessage:message.sortOrder inboxHash:message.inboxHash] completion:nil];
        }
    }
}

- (void)deleteMessages:(NSArray<PWInboxMessageInternal *> *)messages {
    for (PWInboxMessageInternal *message in messages) {
        if (message.canUpdateStatus) {
            [_requestManager sendRequest:[PWInboxUpdateStatusRequest deleteInboxMessage:message.sortOrder inboxHash:message.inboxHash] completion:nil];
        }
    }
    
    [self removeMessagesFromNotificationCenter:messages];
}

- (void)actionMessages:(NSArray<PWInboxMessageInternal *> *)messages {
    for (PWInboxMessageInternal *message in messages) {
        if (message.canUpdateStatus) {
            [_requestManager sendRequest:[PWInboxUpdateStatusRequest actionInboxMessage:message.sortOrder inboxHash:message.inboxHash] completion:nil];
        }
    }
    
    [self removeMessagesFromNotificationCenter:messages];
}

- (void)removeMessagesFromNotificationCenter:(NSArray<PWInboxMessageInternal *> *)messages {
    [[UNUserNotificationCenter currentNotificationCenter] getDeliveredNotificationsWithCompletionHandler:^(NSArray<UNNotification *> * _Nonnull notifications) {
        NSMutableArray *identifiersToDelete = [NSMutableArray new];
        
        for (PWInboxMessageInternal *message in messages) {
            for (UNNotification *notification in notifications) {
                NSString *inboxID = notification.request.content.userInfo[@"pw_inbox"];
                
                if (inboxID) {
                    if ([message.code isEqualToString:inboxID] && notification.request.identifier) {
                        [identifiersToDelete addObject:notification.request.identifier];
                    }
                }
            }
        }
        
        if (identifiersToDelete.count) {
            [[UNUserNotificationCenter currentNotificationCenter] removeDeliveredNotificationsWithIdentifiers:identifiersToDelete];
        }
    }];
}

@end
