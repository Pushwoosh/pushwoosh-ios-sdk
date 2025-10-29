//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWRequest.h"

@interface PWGetResourcesRequest : PWRequest

@property (nonatomic, readonly, copy) NSDictionary *resources;

@end
