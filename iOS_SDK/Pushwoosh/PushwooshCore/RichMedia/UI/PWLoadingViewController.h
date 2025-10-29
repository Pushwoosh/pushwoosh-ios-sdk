//
//  PWLoadingViewController.h
//  Pushwoosh
//
//  Created by Victor Eysner on 05/12/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//
#if TARGET_OS_IOS || TARGET_OS_WATCH
#import "PWBaseLoadingViewController.h"

@interface PWLoadingViewController : PWBaseLoadingViewController

@property (nonatomic) dispatch_block_t cancelBlock;

+ (instancetype)showLoading;

@end
#endif
