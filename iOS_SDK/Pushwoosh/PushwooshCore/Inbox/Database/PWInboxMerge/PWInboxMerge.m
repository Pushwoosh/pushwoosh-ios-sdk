//
//  PWInboxMerge.m
//  Pushwoosh
//
//  Created by Victor Eysner on 31/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInboxMerge.h"
#import "PWInboxMessageInternal+Status.h"
#import "PWInboxStorage.h"

@implementation PWInboxMerge

- (void)mergeServiceMessages:(NSDictionary<NSString *, PWInboxMessageInternal *> *)serviceMessages
                  andStorage:(PWInboxStorage *)storageMessages
                  completion:(void (^)(NSArray<PWInboxMessageInternal *> *needUpdateStatusMessages,
                                       NSArray<PWInboxMessageInternal *> *updateMessages))completion {
    NSMutableArray<PWInboxMessageInternal *> *needUpdateStatusMessages = [NSMutableArray new];
    NSMutableArray<PWInboxMessageInternal *> *updatedMessages = [NSMutableArray new];
    
    for (PWInboxMessageInternal *serviceMessage in serviceMessages.allValues) {
        PWInboxMessageInternal *storageMessage = [storageMessages messageForCode:serviceMessage.code];
        
        if (storageMessage && storageMessage.status != serviceMessage.status) {
            
            if ([storageMessage canUpdateStatus:serviceMessage.status]) {
                [updatedMessages addObject:serviceMessage];
            }
            if ([serviceMessage updateStatus:storageMessage.status]) {
                [needUpdateStatusMessages addObject:serviceMessage];
            }
        }
    }
    
    if (completion) {
        completion(needUpdateStatusMessages, updatedMessages);
    }
}

@end
