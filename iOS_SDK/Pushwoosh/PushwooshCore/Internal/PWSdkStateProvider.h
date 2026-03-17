//
//  PWSdkStateProvider.h
//  PushwooshCore
//
//  Created by André Kis
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PWSdkState) {
    PWSdkStateInitializing,
    PWSdkStateReady,
    PWSdkStateError
};

NS_ASSUME_NONNULL_BEGIN

@interface PWSdkStateProvider : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) PWSdkState currentState;

- (BOOL)isReady;

- (void)executeOrQueue:(dispatch_block_t)task;

- (void)setReady;

- (void)setError;

@end

NS_ASSUME_NONNULL_END
