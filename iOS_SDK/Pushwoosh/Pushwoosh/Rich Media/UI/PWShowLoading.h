//
//  PWShowLoading.h
//  Pushwoosh
//
//  Created by Victor Eysner on 05/12/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PWShowLoading : NSObject

+ (void)showLoading;
+ (void)hideLoading;
+ (void)showLoadingWithCancelBlock:(dispatch_block_t)cancelBlock;

@end
