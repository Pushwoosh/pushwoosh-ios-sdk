//
//  PWInboxMessagesRequest.h
//  Pushwoosh.ios
//
//  Created by Victor Eysner on 19/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWBaseInboxRequest.h"

@class PWInboxMessageInternal;
@interface PWInboxMessagesRequest : PWBaseInboxRequest

@property (nonatomic) NSMutableDictionary<NSString *, PWInboxMessageInternal *> *messages;

- (instancetype)initWithLastInboxCode:(NSString *)inboxCode limit:(NSInteger)limit lastRequestTime:(NSDate *)lastRequestTime;

@end
