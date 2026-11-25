//
//  PWDeliveryDelayTestSeams.h
//  PushwooshTests
//
//  Created by André Kis
//

#import "PWDeliveryDelayWindow.h"
#import "PWDelayedDeliveryUploader.h"

NS_ASSUME_NONNULL_BEGIN

@interface PWDeliveryDelayWindow (DeliveryDelayTestSeams)

/// A block returning a unit value in [0, 1]; nil restores arc4random.
+ (void)setUnitRandomProvider:(nullable double (^)(void))provider;

@end

@interface PWDelayedDeliveryUploader (DeliveryDelayTestSeams) <NSURLSessionTaskDelegate>

+ (instancetype)sharedUploader;
+ (nullable NSURL *)containerURLForAppGroup:(nullable NSString *)appGroupsName;
+ (NSURLSession *)sessionForAppGroup:(nullable NSString *)appGroupsName;
+ (NSURLSession *)sessionWithIdentifier:(NSString *)identifier appGroupsName:(nullable NSString *)appGroupsName;
+ (NSURLSessionConfiguration *)sessionConfigurationWithIdentifier:(NSString *)identifier appGroupsName:(nullable NSString *)appGroupsName;

@end

NS_ASSUME_NONNULL_END
