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

/// Reports after every resource in the getInApps response has been downloaded and unpacked.
- (void)synchronize:(void(^)(NSError *error))completion;

/// Reports as soon as the getInApps response has been stored, with the resource downloads it
/// started still running in the background.
- (void)synchronizeCatalog:(void(^)(NSError *error))completion;
- (void)resetBlocks;

+ (void)destroy;

@end
#endif
