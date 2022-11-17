//
//  PWBusinessCaseManager.h
//  Pushwoosh.ios
//
//  Created by Fectum on 30/01/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
@class PWResource;

typedef NS_ENUM(NSUInteger, PWBusinessCaseResult) {
    PWBusinessCaseResultSuccess,
    PWBusinessCaseResultNotEnabled,     // this business case is not enabled
    PWBusinessCaseResultConditionFail,  // condition was not successful
    PWBusinessCaseResultCappingFail,    // business case has already be triggered maximum allowed number of times
    PWBusinessCaseResultIntervalFail,   // too little time has passed since last presenting
    PWBusinessCaseResultTimeout,        // resource loading timed out
    PWBusinessCaseResultPresentingError // resource loaded but failed to present
};

typedef NS_ENUM(NSUInteger, PWBusinessCasesLoadingState) {
    PWBusinessCasesLoadingStateUnknown,
    PWBusinessCasesLoadingStateKnownCodes,      //after applicationOpen
    PWBusinessCasesLoadingStateResourcesLoaded  //after getInApps
};

FOUNDATION_EXPORT NSString * const kPWWelcomeBusinessCase;
FOUNDATION_EXPORT NSString * const kPWUpdateBusinessCase;
FOUNDATION_EXPORT NSString * const kPWIncreaseRateBusinessCase;
FOUNDATION_EXPORT NSString * const kPWRecoveryBusinessCase;

typedef void(^PWBusinessCaseCompletionBlock)(PWBusinessCaseResult result);

@interface PWBusinessCaseManager : NSObject

@property (nonatomic, readonly) PWBusinessCasesLoadingState loadingState;

+ (instancetype)sharedManager;

- (void)startBusinessCase:(NSString *)identifier completion:(PWBusinessCaseCompletionBlock)completion;

- (void)handleBusinessCaseResources:(NSDictionary *)resources;

- (void)resourceDidClosed:(PWResource *)resource;

- (void)resetCappings;

- (void)fullReset;

@end
