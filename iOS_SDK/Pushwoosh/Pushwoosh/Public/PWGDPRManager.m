//
//  PushNotificationManager.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2018
//

#import "PWGDPRManager.h"
#import "PWInAppManager.h"
#import "Pushwoosh+Internal.h"
#import "PWPushNotificationsManager+Internal.h"
#import "PWGDPRManager+Internal.h"
#import "PWUtils.h"
#import "Constants.h"

#if TARGET_OS_IOS || TARGET_OS_OSX
#import "PWMessageViewController.h"
#import "PWRichMedia+Internal.h"
#endif

NSString * const kCommunicationEnabledKey = @"com.pushwoosh.communicationEnabled";
NSString * const kDataRemovedKey = @"com.pushwoosh.kDataRemovedKey";

NSString * const PWGDPRStatusDidChangeNotification = @"com.pushwoosh.PWGDPRStatusDidChangeNotification";

typedef void (^Completion)(NSError *error);

@interface PWGDPRManager ()

@property (nonatomic) BOOL communicationEnabled;

@property (nonatomic) BOOL deviceDataRemoved;

@end

@implementation PWGDPRManager

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

- (void)setCommunicationEnabled:(BOOL)enabled completion:(void (^)(NSError *error))completion {
    [self performGDPRAction:^(void (^completion)(NSError *error)) {
        [[PWInAppManager sharedManager] postEvent:@"GDPRConsent" withAttributes:@{@"channel" : @(enabled), @"device_type" : @(DEVICE_TYPE)} completion:^(NSError *error) {
            if (!error) {
                if (!enabled) {
                    [[Pushwoosh sharedInstance].pushNotificationManager unregisterForPushNotificationsWithCompletion:^(NSError *error) {
                        if (!error) {
                            self.communicationEnabled = enabled;
                        }
                        
                        if (completion) {
                            completion(error);
                        }
                    }];
                } else {
                    [[Pushwoosh sharedInstance].pushNotificationManager internalRegisterForPushNotifications];
                    
                    self.communicationEnabled = enabled;
                    
                    if (completion) {
                        completion(error);
                    }
                }
            } else {
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:error.localizedDescription];
                
                if (completion) {
                    completion(error);
                }
            }
        }];
    } completion:completion];
}

- (void)removeAllDeviceDataWithCompletion:(void (^)(NSError *error))completion {
    [self performGDPRAction:^(void (^completion)(NSError *error)) {
        [[PWInAppManager sharedManager] postEvent:@"GDPRDelete" withAttributes:@{@"status" : @(YES), @"device_type" : @(DEVICE_TYPE)} completion:^(NSError *error) {
            if (!error) {
                [[Pushwoosh sharedInstance].pushNotificationManager unregisterForPushNotificationsWithCompletion:^(NSError *error) {
                    if (error) {
                        if (completion) {
                            completion(error);
                        }
                    } else {
                        [[PushNotificationManager pushManager] loadTags:^(NSDictionary *tags) {
                            NSMutableDictionary *emptyTags = [NSMutableDictionary new];
                            
                            for (NSString *key in tags.allKeys) {
                                emptyTags[key] = [NSNull null];
                            }
                            
                            [[PushNotificationManager pushManager] setTags:emptyTags withCompletion:^(NSError *error) {
                                if (!error) {
                                    self.deviceDataRemoved = YES;
                                }
                                
                                if (completion) {
                                    completion(error);
                                }
                            }];
                        } error:^(NSError *error) {
                            [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:error.localizedDescription];
                            
                            if (completion) {
                                completion(error);
                            }
                        }];
                    }
                }];
            } else {
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:error.localizedDescription];

                if (completion) {
                    completion(error);
                }
            }
        }];
    } completion:completion];
}

#if TARGET_OS_IOS || TARGET_OS_OSX

- (void)showGDPRConsentUI {
    if (self.gdprConsentResource) {
        PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:self.gdprConsentResource];
        [PWMessageViewController presentWithRichMedia:richMedia];
    }
}

- (void)showGDPRDeletionUI {
    if (self.gdprDeletionResource) {
        PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:self.gdprDeletionResource];
        [PWMessageViewController presentWithRichMedia:richMedia];
    }
}
#endif

- (void)performGDPRAction:(void (^)(void (^completion)(NSError *error)))action completion:(void (^)(NSError *error))completion {
    void (^innerCompletion)(NSError *error) = ^(NSError *error) {
        if (!error) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PWGDPRStatusDidChangeNotification object:self];
        }
        
        completion(error);
    };
    
    if (self.isAvailable) {
        action(innerCompletion);
    } else {
        NSString *logString = @"The GDPR solution isn’t available for this account";
        
        [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:logString];

        if (completion) {
            completion([PWUtilsCommon pushwooshErrorWithCode:PWErrorGDPRNotAvailable description:logString]);
        }
    }
}

- (void)reset {
    _available = NO;
    _deviceDataRemoved = NO;
    _communicationEnabled = YES;
}

@end
