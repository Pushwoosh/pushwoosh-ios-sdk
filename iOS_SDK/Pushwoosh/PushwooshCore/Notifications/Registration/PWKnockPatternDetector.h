//
//  PWKnockPatternDetector.h
//  PushwooshCore
//
//  Created by André Kis on 07.04.26.
//

#import <Foundation/Foundation.h>

#if TARGET_OS_IOS

NS_ASSUME_NONNULL_BEGIN

typedef NSTimeInterval (^PWKnockClockBlock)(void);

@interface PWKnockPatternDetector : NSObject

+ (instancetype)sharedDetector;

- (instancetype)initWithClock:(PWKnockClockBlock)clock;

- (void)startDetection;
- (void)onForeground;

@end

NS_ASSUME_NONNULL_END

#endif
