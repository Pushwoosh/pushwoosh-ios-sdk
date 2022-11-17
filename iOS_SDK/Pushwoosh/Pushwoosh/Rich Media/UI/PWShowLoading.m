//
//  PWShowLoading.m
//  Pushwoosh
//
//  Created by Victor Eysner on 05/12/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWShowLoading.h"
#if TARGET_OS_IOS
#import "PWLoadingViewController.h"
#endif

@interface PWShowLoading()

@property (nonatomic) NSUInteger counter;
#if TARGET_OS_IOS
@property (nonatomic, readonly) PWLoadingViewController *loadingViewController;
#endif

@end

@implementation PWShowLoading

- (instancetype)init {
    if (self = [super init]) {
        _counter = 0;
    }
    return self;
}

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static id sharedInstance;
    dispatch_once(&once, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)showLoading {
#if TARGET_OS_IOS
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        _counter++;
        if (!_loadingViewController) {
            _loadingViewController = [PWLoadingViewController showLoading];
        }
    }];
#endif
}

- (void)hideLoading {
#if TARGET_OS_IOS
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        _counter--;
        if (_counter == 0) {
            [_loadingViewController closeController];
            _loadingViewController = nil;
        }
    }];
#endif
}

+ (void)showLoadingWithCancelBlock:(dispatch_block_t)cancelBlock {
#if TARGET_OS_IOS
    [[self sharedInstance] showLoading];
    [PWShowLoading sharedInstance].loadingViewController.cancelBlock = cancelBlock;
#endif
}

+ (void)showLoading {
    [[self sharedInstance] showLoading];
}

+ (void)hideLoading {
    [[self sharedInstance] hideLoading];
}

@end
