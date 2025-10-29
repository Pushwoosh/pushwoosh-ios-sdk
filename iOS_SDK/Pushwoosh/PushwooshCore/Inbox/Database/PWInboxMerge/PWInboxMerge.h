//
//  PWInboxMerge.h
//  Pushwoosh
//
//  Created by Victor Eysner on 31/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@class PWInboxStorage;
@class PWInboxMessageInternal;
@interface PWInboxMerge : NSObject

- (void)mergeServiceMessages:(NSDictionary<NSString *, PWInboxMessageInternal *> *)serviceMessages
                  andStorage:(PWInboxStorage *)storageMessages
                  completion:(void (^)(NSArray<PWInboxMessageInternal *> *needUpdateStatusMessages,
                                       NSArray<PWInboxMessageInternal *> *updateMessages))completion;

@end
