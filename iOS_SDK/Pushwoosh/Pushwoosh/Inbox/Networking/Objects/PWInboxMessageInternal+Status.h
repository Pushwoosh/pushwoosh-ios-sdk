//
//  PWInboxMessageInternal+Network.h
//  Pushwoosh
//
//  Created by Victor Eysner on 25/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInboxMessageInternal.h"

@interface PWInboxMessageInternal (Status)

- (BOOL)canUpdateStatus:(PWInboxMessageStatus)status;
- (BOOL)updateStatus:(PWInboxMessageStatus)status;
+ (NSInteger)readStatusForNetwork;
+ (NSInteger)actionStatusForNetwork;
+ (NSInteger)deleteStatusForNetwork;

@end
