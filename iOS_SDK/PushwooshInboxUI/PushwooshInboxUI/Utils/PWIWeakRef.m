//
//  PWWeakRef.m
//  PushNotificationManager
//
//  Created by Pushwoosh on 23/08/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWIWeakRef.h"

@implementation PWIWeakRef

+ (instancetype) refWithObject:(id) object {
    PWIWeakRef *ref = [PWIWeakRef new];
    ref.object = object;
    return ref;
}

@end
