//
//  PWBusinessCase.h
//  Pushwoosh
//
//  Created by Fectum on 30/01/2018.
//  Copyright © 2018 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWBusinessCaseManager.h"

typedef BOOL(^PWBusinessCaseConditionBlock)();

@interface PWBusinessCase : NSObject

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic) PWBusinessCaseConditionBlock conditionBlock;
@property (nonatomic) dispatch_block_t onCloseBlock;
@property (nonatomic) NSTimeInterval timeout;
@property (nonatomic) NSUInteger maxTriggeredCount; //how many times this case could be triggered
@property (nonatomic) NSTimeInterval minimumPresentingInterval; //how often this case could be presenting
@property (nonatomic, readonly) NSDate *lastPresentingDate;
@property (nonatomic, readonly) NSString *resourceCode;
@property (nonatomic, readonly) NSTimeInterval resourceUpdated;

- (instancetype)initWithIdentifier:(NSString *)identifier;

- (void)startWithResourceDict:(NSDictionary *)resourceDict loadingState:(PWBusinessCasesLoadingState)loadingState completion:(PWBusinessCaseCompletionBlock)completion;

- (void)stop;

- (void)handleResource:(NSDictionary *)resourceDict loadingState:(PWBusinessCasesLoadingState)loadingState;

- (void)resetCapping;

@end
