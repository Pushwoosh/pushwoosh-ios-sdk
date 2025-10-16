//
//  PWInAppStorage.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#if TARGET_OS_IOS || TARGET_OS_TV
#import <Foundation/Foundation.h>

@class PWResource;

@interface PWInAppStorage : NSObject

+ (instancetype)storage;

- (PWResource *)resourceForCode:(NSString *)code;
- (void)resourcesForCode:(NSString *)code completionBlock:(void (^)(PWResource *resource))completion;

- (PWResource *)resourceForDictionary:(NSDictionary *)dict;

- (void)synchronize:(void(^)(NSError *error))completion;
- (void)resetBlocks;

+ (void)destroy;

@end
#endif
