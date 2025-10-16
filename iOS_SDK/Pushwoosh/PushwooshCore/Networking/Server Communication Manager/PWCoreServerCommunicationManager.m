//
//  PWCoreServerCommunicationManager.m
//  PushwooshCore
//
//  Created by André Kis on 17.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PWCoreServerCommunicationManager.h"

NSString *const kPWCoreServerCommunicationStarted = @"kPWServerCommunicationStarted";

@implementation PWCoreServerCommunicationManager

@dynamic sharedInstance;

+ (PWCoreServerCommunicationManager *)sharedInstance {
    static PWCoreServerCommunicationManager *instance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

- (BOOL)isServerCommunicationAllowed {
    return [[PWSettings settings] isServerCommunicationEnabled];
}

- (void)startServerCommunication {
    if (self.serverCommunicationAllowed) {
        return;
    }

    [[PWSettings settings] setIsServerCommunicationEnabled:YES];

    [[NSNotificationCenter defaultCenter] postNotificationName:kPWCoreServerCommunicationStarted object:nil];
}

- (void)stopServerCommunication {
    [[PWSettings settings] setIsServerCommunicationEnabled:NO];
}

@end
