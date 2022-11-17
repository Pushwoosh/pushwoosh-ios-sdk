//
//  PWServerCommunicationManager.m
//  Pushwoosh
//  (c) Pushwoosh 2021
//

#import "PWServerCommunicationManager.h"
#import "PWPreferences.h"

NSString *const kPWServerCommunicationStarted = @"kPWServerCommunicationStarted";

@implementation PWServerCommunicationManager

+ (instancetype)sharedInstance {
    static PWServerCommunicationManager *instance = nil;
    static dispatch_once_t pred;

    dispatch_once(&pred, ^{
        instance = [PWServerCommunicationManager new];
    });

    return instance;
}

- (BOOL)isServerCommunicationAllowed {
    return [[PWPreferences preferences] isServerCommunicationEnabled];
}

- (void)startServerCommunication {
    if ([[PWPreferences preferences] isServerCommunicationEnabled]) {
        // already started
        return;
    }
    
    [[PWPreferences preferences] setIsServerCommunicationEnabled:YES];
    
    // send /getInApps, /getConfig, /appOpen if not sent & /registerUser if not sent
     [[NSNotificationCenter defaultCenter] postNotificationName:kPWServerCommunicationStarted object:nil];
}

- (void)stopServerCommunication {
    [[PWPreferences preferences] setIsServerCommunicationEnabled:NO];
}

@end
