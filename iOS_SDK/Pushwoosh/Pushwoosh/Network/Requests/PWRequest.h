//
//  PWRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import <Foundation/Foundation.h>
#import "NSDictionary+PWDictUtils.h"

#define kPrefixDelay @"PrefixDelay"
#define kPrefixDate @"PrefixDate"
#define kPrefixRemainDelay @"PrefixRemainDelay"

@interface PWRequest : NSObject

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
