//
//  PWServerCommunicationManager.m
//  PushwooshCore
//
//  Created by André Kis on 17.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PWServerCommunicationManager.h"

NSString *const kPWServerCommunicationStarted = @"kPWServerCommunicationStarted";

@implementation PWServerCommunicationManager

@dynamic sharedInstance;

+ (PWServerCommunicationManager *)sharedInstance {
    static PWServerCommunicationManager *instance = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });

    return instance;
}

- (BOOL)isServerCommunicationAllowed {
    return [[PWPreferences preferences] isServerCommunicationEnabled];
}

- (void)startServerCommunication {
    if (self.serverCommunicationAllowed) {
        return;
    }

    [[PWPreferences preferences] setIsServerCommunicationEnabled:YES];

    [[NSNotificationCenter defaultCenter] postNotificationName:kPWServerCommunicationStarted object:nil];
}

- (void)stopServerCommunication {
    [[PWPreferences preferences] setIsServerCommunicationEnabled:NO];
}

@end
