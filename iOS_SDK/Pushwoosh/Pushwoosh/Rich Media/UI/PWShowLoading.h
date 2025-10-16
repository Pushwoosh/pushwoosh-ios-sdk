//
//  PWShowLoading.h
//  Pushwoosh
//
//  Created by Victor Eysner on 05/12/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#if TARGET_OS_IOS
#import <Foundation/Foundation.h>

@interface PWShowLoading : NSObject

+ (void)showLoading;
+ (void)hideLoading;
+ (void)showLoadingWithCancelBlock:(dispatch_block_t)cancelBlock;

@end
#endif
