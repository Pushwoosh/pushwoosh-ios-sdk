//
//  PWRequestsCacheManager.h
//  Pushwoosh
//
//  Created by Anton Kaizer on 21.08.17.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PWRequest.h"

@interface PWRequestsCacheManager : NSObject

+ (instancetype)sharedInstance;

- (void)cacheRequest:(PWRequest *)request;
- (void)deleteCachedRequest:(PWRequest *)request;

@end
