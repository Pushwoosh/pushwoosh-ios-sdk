//
//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWRequest.h"

@interface PWPostEventRequest : PWRequest

@property (nonatomic, strong) NSString *event;
@property (nonatomic, strong) NSDictionary *attributes;

//response
@property (nonatomic, readonly, strong) NSString *resultCode;
@property (nonatomic, readonly, strong) NSDictionary *richMedia;
@property (nonatomic, readonly) BOOL required;

@end
