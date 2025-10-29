//
//  PWInboxMessageInternal+Network.m
//  Pushwoosh
//
//  Created by Victor Eysner on 25/10/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWInboxMessageInternal+Status.h"

@interface PWInboxMessageInternal (StatusPrivate)

@property (nonatomic) PWInboxMessageStatus status;

@end

@implementation PWInboxMessageInternal (Status)

+ (NSInteger)actionStatusForNetwork {
    return 3;
}

+ (NSInteger)deleteStatusForNetwork {
    return 4;
}

+ (NSInteger)readStatusForNetwork {
    return 2;
}

- (BOOL)canUpdateStatus:(PWInboxMessageStatus)status {
    if (self.status == status) {
        return NO;
    } else if (self.status == PWInboxMessageStatusCreated) {
        return YES;
    } else {
        
        switch (status) {
            case PWInboxMessageStatusDeleted:
                return YES;
            case PWInboxMessageStatusAction:
                if (self.status == PWInboxMessageStatusRead ||
                    self.status == PWInboxMessageStatusDelivered) {
                    return YES;
                } else {
                    return NO;
                }
            case PWInboxMessageStatusRead:
                if (self.status == PWInboxMessageStatusDelivered) {
                    return YES;
                } else {
                    return NO;
                }
            default:
                break;
        }
        return NO;
        
    }
}

- (BOOL)updateStatus:(PWInboxMessageStatus)status {
    if ([self canUpdateStatus:status]) {
        self.status = status;
        return YES;
    } else {
        return NO;
    }
}

@end
