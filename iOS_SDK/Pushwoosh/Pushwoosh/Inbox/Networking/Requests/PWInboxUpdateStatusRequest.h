//
//  PWInboxUpdateStatusRequest.h
//  Pushwoosh
//
//  Created by Victor Eysner on 25/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWBaseInboxRequest.h"

@interface PWInboxUpdateStatusRequest : PWBaseInboxRequest

+ (instancetype)deleteInboxMessage:(NSString *)inboxCode inboxHash:(NSString *)inboxHash;
+ (instancetype)actionInboxMessage:(NSString *)inboxCode inboxHash:(NSString *)inboxHash;
+ (instancetype)readInboxMessage:(NSString *)inboxCode inboxHash:(NSString *)inboxHash;

@end
