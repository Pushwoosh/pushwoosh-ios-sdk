//
//  PWInboxAllMessagesRequest.h
//  Pushwoosh
//
//  Created by Victor Eysner on 31/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWBaseInboxRequest.h"

@class PWInboxMessageInternal;
@interface PWInboxAllMessagesRequest : PWBaseInboxRequest

@property (nonatomic) NSMutableDictionary<NSString *, PWInboxMessageInternal *> *messages;
@property (nonatomic) NSInteger count;

/// The raw `inbox_tabs` dictionary of the response, `nil` when the key is absent or is not a dictionary.
@property (nonatomic) NSDictionary *tabsPayload;

- (instancetype)initWithLastRequestTime:(NSDate *)lastRequestTime;

@end
