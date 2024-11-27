//
//  PWWeakRef.h
//  PushNotificationManager
//
//  Created by Pushwoosh on 23/08/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PWIWeakRef<Type> : NSObject

@property (nonatomic, weak) Type object;

+ (instancetype) refWithObject:(Type) object;

@end
