//
//  PWIPushwooshHelper.h
//  PushwooshInboxUI
//
//  Created by Pushwoosh on 01/11/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWInbox.h"

@interface PWIPushwooshHelper : NSObject

@property(class, nonatomic, readonly) Class pwInbox;

+ (Class)pwInbox;
+ (BOOL)checkPushwooshFrameworkAvailableAndRunExaptionIfNeeded;

@end
