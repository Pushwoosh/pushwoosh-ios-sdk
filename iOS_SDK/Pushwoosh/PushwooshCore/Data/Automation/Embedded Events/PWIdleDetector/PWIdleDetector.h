//
//  PWIdleDetector.h
//  PushwooshCore
//
//  Created by André Kis on 15.04.26.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const defaultUserIdleEvent;

@interface PWIdleDetector : NSObject

@property (nonatomic) BOOL defaultIdleTrackingAllowed;

+ (instancetype)sharedDetector;

- (instancetype)initWithIdleThreshold:(NSTimeInterval)threshold;

- (void)startTracking;

@end

NS_ASSUME_NONNULL_END

#endif
