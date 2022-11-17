//
//  PWRequestManagerMock.h
//  PushNotificationManager
//
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWRequestManager.h"

#import <Foundation/Foundation.h>

@interface PWRequestManagerMock : PWRequestManager

@property (atomic, strong) void (^onSendRequest)(PWRequest*);

@property (nonatomic, strong) NSDictionary *response;

@property (nonatomic, assign) BOOL failed;

@end
