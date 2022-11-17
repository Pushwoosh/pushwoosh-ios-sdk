//
//  PWBusinessCase.m
//  Pushwoosh
//
//  Created by Fectum on 30/01/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import "PWBusinessCase.h"
#import "PWInAppStorage.h"
#import "PWInAppManager.h"
#import "PWInAppMessagesManager.h"
#import "PWInAppManager+Internal.h"
#import "PWMessageViewController.h"
#import "PWRichMedia+Internal.h"

#define kCurrentTriggeredCountKey(identifier) [NSString stringWithFormat:@"PWCurrentTriggeredCountKey_%@", identifier]
#define kLastPresentingDateKey(identifier) [NSString stringWithFormat:@"PWLastPresentingDateKey_%@", identifier]

@interface PWBusinessCase()

@property (nonatomic) NSUInteger currentTriggeredCount; //number of richmedia impressions

@property (nonatomic) PWBusinessCaseCompletionBlock completion;

@property (nonatomic) BOOL isWaiting;
@property (nonatomic) BOOL isPresenting;

@end

@implementation PWBusinessCase

#pragma mark - Setup

- (instancetype)initWithIdentifier:(NSString *)identifier {
    self = [super init];
    
    if (self) {
        _identifier = identifier;
        _timeout = 4;
        _maxTriggeredCount = 1;
        _currentTriggeredCount = [[NSUserDefaults standardUserDefaults] integerForKey:kCurrentTriggeredCountKey(identifier)];
        
        NSNumber *lastPresentingDate = [[NSUserDefaults standardUserDefaults] objectForKey:kLastPresentingDateKey(identifier)];
        
        if (lastPresentingDate) {
            _lastPresentingDate = [NSDate dateWithTimeIntervalSinceReferenceDate:lastPresentingDate.doubleValue];
        }
    }
    
    return self;
}

#pragma Control Flow

- (void)startWithResourceDict:(NSDictionary *)resourceDict loadingState:(PWBusinessCasesLoadingState)loadingState completion:(PWBusinessCaseCompletionBlock)completion {
    _completion = completion;
    
    CGFloat intervalSinceLastPresenting = _lastPresentingDate ? [NSDate date].timeIntervalSinceReferenceDate - _lastPresentingDate.timeIntervalSinceReferenceDate : 0;
    
    BOOL conditionResult = _conditionBlock ? _conditionBlock() : YES;
    BOOL cappingResult = (_maxTriggeredCount == 0 || _currentTriggeredCount < _maxTriggeredCount);
    BOOL intervalResult = (_minimumPresentingInterval == 0 || intervalSinceLastPresenting == 0 || intervalSinceLastPresenting > _minimumPresentingInterval);
    
    if (cappingResult && intervalResult && conditionResult) {
        [self handleResource:resourceDict loadingState:loadingState];
    } else {
        PWBusinessCaseResult result;
        
        if (!conditionResult) {
            result = PWBusinessCaseResultConditionFail;
        } else if (!cappingResult) {
            result = PWBusinessCaseResultCappingFail;
        } else {
            result = PWBusinessCaseResultIntervalFail;
        }
        
        completion(result);
    }
}

- (void)stop {
    [self stopWaiting];
    _completion(PWBusinessCaseResultNotEnabled);
}

- (void)setCurrentTriggeredCount:(NSUInteger)currentTriggeredCount {
    _currentTriggeredCount = currentTriggeredCount;
    [[NSUserDefaults standardUserDefaults] setInteger:_currentTriggeredCount forKey:kCurrentTriggeredCountKey(_identifier)];
}

- (void)setLastPresentingDate:(NSDate *)lastPresentingDate {
    _lastPresentingDate = lastPresentingDate;
    [[NSUserDefaults standardUserDefaults] setDouble:lastPresentingDate.timeIntervalSinceReferenceDate forKey:kLastPresentingDateKey(_identifier)];
}

#pragma mark - Handle Resource

- (void)startWaiting {
    _isWaiting = YES;
    [self performSelector:@selector(waitingTimedOut) withObject:nil afterDelay:_timeout];
}

- (void)stopWaiting {
    _isWaiting = NO;
     [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(waitingTimedOut) object:nil];
}

- (void)waitingTimedOut {
    _isWaiting = NO;
    _completion(PWBusinessCaseResultTimeout);
}

//called after /appOpen and /getInApps and also right after start
- (void)handleResource:(NSDictionary *)resourceDict loadingState:(PWBusinessCasesLoadingState)loadingState {
    if (_isPresenting) {
        return;
    }
    
    _resourceCode = resourceDict[@"code"];
    _resourceUpdated = [resourceDict[@"updated"] doubleValue];
    
    BOOL shouldWait = YES;
    
    if (_resourceCode) {
        PWResource *resource = [[PWInAppStorage storage] resourceForCode:_resourceCode];
        
        if (resource && resource.updated == _resourceUpdated) {
            shouldWait = NO;
            
            [self stopWaiting];
            
            self.lastPresentingDate = [NSDate date];
            
            _isPresenting = YES;
            
            PWRichMedia *richMedia = [[PWRichMedia alloc] initWithSource:PWRichMediaSourceInApp resource:resource];
            [PWMessageViewController presentWithRichMedia:richMedia completion:^(BOOL success) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (success) {
                        _completion(PWBusinessCaseResultSuccess);
                    } else {
                        _completion(PWBusinessCaseResultPresentingError);
                    }
                    
                    self.currentTriggeredCount++;
                });
            }];
        }
    } else if (loadingState != PWBusinessCasesLoadingStateUnknown) {
        shouldWait = NO;
        [self stop];
    }
    
    if (shouldWait && !_isWaiting) {
        [self startWaiting];
    }
}

- (void)resetCapping {
    self.currentTriggeredCount = 0;
    self.lastPresentingDate = nil;
}

@end
