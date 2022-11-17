//
//  PWServerCommunicationManager.m
//  Pushwoosh
//  (c) Pushwoosh 2021
//

#import <Foundation/Foundation.h>

extern NSString *const kPWServerCommunicationStarted;

@interface PWServerCommunicationManager : NSObject

+ (instancetype)sharedInstance;

- (BOOL)isServerCommunicationAllowed;

- (void)startServerCommunication;

- (void)stopServerCommunication;

@end
