//
//  PWCache.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import <Foundation/Foundation.h>

@interface PWCache : NSObject

+ (PWCache*)cache;

- (void)setTags:(NSDictionary*)tags;

- (void)addTags:(NSDictionary*)tags;

- (NSDictionary*)getTags;

- (void)setEmailTags:(NSDictionary *)tags;

- (void)addEmailTags:(NSDictionary *)tags;

- (NSDictionary *)getEmailTags;

- (void)clear;

- (void)clearEmailTags;

@end
