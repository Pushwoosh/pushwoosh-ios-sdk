//
//  PWBusinessCaseManager.m
//  Pushwoosh.ios
//
//  Created by Fectum on 30/01/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import "PWBusinessCaseManager.h"
#import "PWBusinessCase.h"
#import "PWVersionTracking.h"
#import "PWResource.h"
#import "PushNotificationManager.h"
#import "Pushwoosh+Internal.h"
#import "PWPreferences.h"

NSString * const kPWWelcomeBusinessCase = @"welcome-inapp";
NSString * const kPWUpdateBusinessCase = @"app-update-message";
NSString * const kPWIncreaseRateBusinessCase = @"subscription-segments";
NSString * const kPWRecoveryBusinessCase = @"push-unregister";

@interface PWBusinessCaseManager ()

@property (nonatomic) NSMutableDictionary *activeCases;
@property (nonatomic) NSDictionary *resources;

@end

@implementation PWBusinessCaseManager

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
        _activeCases = [NSMutableDictionary new];
    }
    return self;
}

- (void)startBusinessCase:(NSString *)identifier completion:(PWBusinessCaseCompletionBlock)completion {
    if (identifier) {
        PWBusinessCase *businessCase = _activeCases[identifier];
        
        if (!businessCase) {
            businessCase = [self.class businessCasesDictionary][identifier];
            
            if (!businessCase) {
                PWLogWarn(@"Unknown business case %@", identifier);
                return;
            }
            
            _activeCases[identifier] = businessCase;
            
            __weak typeof (self) wself = self;
            
            NSDictionary *resourceDict = _resources[identifier];
            
            [businessCase startWithResourceDict:resourceDict loadingState:_loadingState completion:^(PWBusinessCaseResult result) {
                wself.activeCases[identifier] = nil;
                
                if (completion) {
                    completion(result);
                }
            }];
        } else {
            PWLogInfo(@"Business case is already active");
        }
    }
}

- (void)handleBusinessCaseResources:(NSDictionary *)resources {
    NSDictionary *finalDictionary = nil;
    
    _loadingState = PWBusinessCasesLoadingStateKnownCodes;
    
    if (resources && [resources isKindOfClass:[NSDictionary class]]) {
        id value = resources.allValues.firstObject;
        
        if (value) {
            if ([value isKindOfClass:[NSDictionary class]]) {//this is from appOpen
                finalDictionary = resources;
            } else if ([value isKindOfClass:[PWResource class]]) { //this is from getInApps
                NSMutableDictionary *resourceDict = [NSMutableDictionary new];
                
                for (NSString *code in resources.allKeys) {
                    PWResource *resource = resources[code];
                    
                    if (resource.businessCase) {
                        resourceDict[resource.businessCase] = @{@"code" : resource.code, @"updated" : @(resource.updated)};
                    }
                }
                
                finalDictionary = resourceDict;
                
                _loadingState = PWBusinessCasesLoadingStateResourcesLoaded;
            }
        }
    }
    
    _resources = finalDictionary;
    
    if (_resources) {
        for (NSString *identifier in _activeCases.allKeys) {
            NSDictionary *resourceDict = _resources[identifier];
            PWBusinessCase *activeCase = _activeCases[identifier];
            
            if (resourceDict) {
                [activeCase handleResource:resourceDict loadingState:_loadingState];
            } else {
                [activeCase stop];
            }
        }
    }
}

+ (NSDictionary *)businessCasesDictionary {
    NSNumber *cappingInDays = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"Pushwoosh_InAppBusinessSolutionsCapping"];
    
    if (!cappingInDays) {
        cappingInDays = @(1);// once a day by default
    }
    
    NSTimeInterval cappingInSeconds = 60 * 60 * 24 * cappingInDays.floatValue;
    
    PWBusinessCase *welcomeCase = [[PWBusinessCase alloc] initWithIdentifier:kPWWelcomeBusinessCase];
    welcomeCase.conditionBlock = ^BOOL {
        return [PWVersionTracking isFirstLaunchEver];
    };
    
    PWBusinessCase *updateCase = [[PWBusinessCase alloc] initWithIdentifier:kPWUpdateBusinessCase];
    updateCase.conditionBlock = ^BOOL {
        return [PWVersionTracking isFirstLaunchForVersion];
    };
    updateCase.maxTriggeredCount = 0; //infinitely
    
    PWBusinessCase *increasePushRateCase = [[PWBusinessCase alloc] initWithIdentifier:kPWIncreaseRateBusinessCase];
    increasePushRateCase.conditionBlock = ^BOOL {
        return [Pushwoosh sharedInstance].getPushToken == nil && ![PWPreferences preferences].registrationEverOccured;
    };
    increasePushRateCase.minimumPresentingInterval = cappingInSeconds;
    increasePushRateCase.maxTriggeredCount = 0; //infinitely
    
    PWBusinessCase *recoveryPushCase = [[PWBusinessCase alloc] initWithIdentifier:kPWRecoveryBusinessCase];
    recoveryPushCase.conditionBlock = ^BOOL {
        NSDictionary *dict = [PushNotificationManager getRemoteNotificationStatus];
        BOOL alertsEnabled = [dict[@"pushAlert"] boolValue];
        return !alertsEnabled && [PWPreferences preferences].registrationEverOccured;
    };
    
    recoveryPushCase.minimumPresentingInterval = cappingInSeconds;
    recoveryPushCase.maxTriggeredCount = 0; //infinitely
    
    return @{welcomeCase.identifier : welcomeCase,
             updateCase.identifier : updateCase,
             increasePushRateCase.identifier : increasePushRateCase,
             recoveryPushCase.identifier : recoveryPushCase
             };
}

- (void)resourceDidClosed:(PWResource *)resource {
    for (NSString *identifier in _resources.allKeys) {
        NSDictionary *dict = _resources[identifier];
        
        if ([dict[@"code"] isEqualToString:resource.code]) {
            PWBusinessCase *businessCase = _activeCases[identifier];
            
            if (businessCase.onCloseBlock) {
                businessCase.onCloseBlock();
            }
        }
    }
}

- (void)resetCappings {
    NSDictionary *businessCases = [self.class businessCasesDictionary];
    
    for (PWBusinessCase *businessCase in businessCases.allValues) {
        [businessCase resetCapping];
    }
}

- (void)fullReset {
    _resources = nil;
    _loadingState = PWBusinessCasesLoadingStateUnknown;
    _activeCases = [NSMutableDictionary new];
    
    [PWPreferences preferences].registrationEverOccured = NO;
    [PWVersionTracking reset];
    
    NSDictionary *defaultsDict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    
    for (NSString *key in [defaultsDict allKeys])
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
