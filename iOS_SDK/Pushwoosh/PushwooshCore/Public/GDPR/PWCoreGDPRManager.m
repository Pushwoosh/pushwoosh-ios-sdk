//
//  PWCoreGDPRManager.m
//  PushwooshCore
//
//  Created by André Kis on 17.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PWCoreGDPRManager.h"
#import "PWCoreServerCommunicationManager.h"

NSString * const kCommunicationEnabledKey = @"com.pushwoosh.communicationEnabled";
NSString * const kDataRemovedKey = @"com.pushwoosh.kDataRemovedKey";

NSString * const PWGDPRStatusDidChangeNotification = @"com.pushwoosh.PWGDPRStatusDidChangeNotification";

typedef void (^Completion)(NSError *error);

@interface PWCoreGDPRManager ()

@property (nonatomic) BOOL communicationEnabled;

@property (nonatomic) BOOL deviceDataRemoved;

@end

@implementation PWCoreGDPRManager

+ (Class<PWGDPR>)GDPR {
    return self;
}

+ (instancetype)sharedManager {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        NSNumber *communicationEnabled = [[NSUserDefaults standardUserDefaults] objectForKey:kCommunicationEnabledKey];
        
        if (communicationEnabled) {
            _communicationEnabled = communicationEnabled.boolValue;
        } else {
            _communicationEnabled = YES;
        }
        
        NSNumber *deviceDataRemoved = [[NSUserDefaults standardUserDefaults] objectForKey:kDataRemovedKey];
        
        if (deviceDataRemoved) {
            _deviceDataRemoved = deviceDataRemoved.boolValue;
        } else {
            _deviceDataRemoved = NO;
        }
    }
    return self;
}

- (void)setCommunicationEnabled:(BOOL)communicationEnabled {
    _communicationEnabled = communicationEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:communicationEnabled forKey:kCommunicationEnabledKey];
}

- (void)setDeviceDataRemoved:(BOOL)deviceDataRemoved {
    _deviceDataRemoved = deviceDataRemoved;
    [[NSUserDefaults standardUserDefaults] setBool:deviceDataRemoved forKey:kDataRemovedKey];
}

- (void)removeAllDeviceDataWithCompletion:(nonnull void (^)(NSError * _Nonnull))completion {}

- (void)setCommunicationEnabled:(BOOL)enabled completion:(nonnull void (^)(NSError * _Nonnull))completion {}

- (void)showGDPRConsentUI {}

- (void)showGDPRDeletionUI {}

@end
