//
//  PWSdkStateProvider.m
//  PushwooshCore
//
//  Created by André Kis
//

#import "PWSdkStateProvider.h"
#import "PushwooshLog.h"

@interface PWSdkStateProvider ()

@property (nonatomic) PWSdkState currentState;
@property (nonatomic, strong) NSMutableArray<dispatch_block_t> *taskQueue;
@property (nonatomic, strong) NSObject *lock;

@end

@implementation PWSdkStateProvider

+ (instancetype)sharedInstance {
    static PWSdkStateProvider *instance = nil;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        instance = [[PWSdkStateProvider alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _currentState = PWSdkStateInitializing;
        _taskQueue = [NSMutableArray new];
        _lock = [NSObject new];
    }
    return self;
}

- (BOOL)isReady {
    @synchronized (_lock) {
        return _currentState == PWSdkStateReady;
    }
}

- (void)executeOrQueue:(dispatch_block_t)task {
    @synchronized (_lock) {
        if (_currentState == PWSdkStateReady) {
            task();
        } else if (_currentState == PWSdkStateInitializing) {
            [_taskQueue addObject:[task copy]];
            [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:@"SDK is initializing, task queued."];
        } else {
            [PushwooshLog pushwooshLog:PW_LL_WARN className:self message:@"SDK is in ERROR state, task ignored."];
        }
    }
}

- (void)setReady {
    NSArray<dispatch_block_t> *tasksToRun;

    @synchronized (_lock) {
        if (_currentState != PWSdkStateInitializing) {
            return;
        }
        tasksToRun = [_taskQueue copy];
        [_taskQueue removeAllObjects];
        _currentState = PWSdkStateReady;
    }

    [PushwooshLog pushwooshLog:PW_LL_DEBUG className:self message:[NSString stringWithFormat:@"SDK ready. Executing %lu queued tasks.", (unsigned long)tasksToRun.count]];

    dispatch_async(dispatch_get_main_queue(), ^{
        for (dispatch_block_t task in tasksToRun) {
            @try {
                task();
            } @catch (NSException *exception) {
                [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"Error executing queued task: %@", exception]];
            }
        }
    });
}

- (void)setError {
    NSUInteger droppedCount;
    @synchronized (_lock) {
        _currentState = PWSdkStateError;
        droppedCount = _taskQueue.count;
        [_taskQueue removeAllObjects];
    }
    [PushwooshLog pushwooshLog:PW_LL_ERROR className:self message:[NSString stringWithFormat:@"SDK state changed to ERROR. %lu queued tasks dropped.", (unsigned long)droppedCount]];
}

#if DEBUG
- (void)resetForTesting {
    @synchronized (_lock) {
        _currentState = PWSdkStateInitializing;
        [_taskQueue removeAllObjects];
    }
}
#endif

@end
