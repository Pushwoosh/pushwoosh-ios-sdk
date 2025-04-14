//
//  PWCoreRequest.h
//  PushwooshCore
//
//  Created by André Kis on 12.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kPrefixDelay @"PrefixDelay"
#define kPrefixDate @"PrefixDate"
#define kPrefixRemainDelay @"PrefixRemainDelay"

NS_ASSUME_NONNULL_BEGIN

@interface PWCoreRequest : NSObject

@property (nonatomic, assign) NSInteger httpCode;
@property (nonatomic) BOOL cacheable;
@property (nonatomic) BOOL usePreviousHWID;
@property (nonatomic) int startTime;

- (NSString *)uid;
- (NSString *)methodName;
- (NSDictionary *)requestDictionary;
- (NSString *)requestIdentifier;

- (NSMutableDictionary *)baseDictionary;
- (void)parseResponse:(NSDictionary *)response;

@end

NS_ASSUME_NONNULL_END
