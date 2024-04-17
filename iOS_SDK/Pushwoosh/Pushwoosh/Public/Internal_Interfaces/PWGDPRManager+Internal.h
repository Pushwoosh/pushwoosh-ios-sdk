//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2018
//

#import "PWGDPRManager.h"

@interface PWGDPRManager ()

@property (nonatomic) BOOL available;

#if TARGET_OS_IOS || TARGET_OS_OSX
@property (nonatomic) PWResource *gdprConsentResource;
@property (nonatomic) PWResource *gdprDeletionResource;
#endif

- (void)reset;

@end
