//
//  PWMergeUserRequest.h
//  PushNotificationManager
//
//  Created by User on 29/09/15.
//
//

#import "PWRequest.h"

@interface PWMergeUserRequest : PWRequest

@property (nonatomic, copy) NSString *srcUserId;
@property (nonatomic, copy) NSString *dstUserId;
@property (nonatomic, assign) BOOL doMerge;

@end
