//
//  PWApplicationExitDetector.h
//  PushwooshCore
//
//  Created by André Kis on 27.04.26.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const defaultApplicationExitEvent;

@interface PWApplicationExitDetector : NSObject

@property (nonatomic) BOOL defaultApplicationExitTrackingAllowed;

+ (instancetype)sharedDetector;

- (instancetype)initWithExitTimeout:(NSTimeInterval)timeout;

- (void)startTracking;

@end

NS_ASSUME_NONNULL_END

#endif
