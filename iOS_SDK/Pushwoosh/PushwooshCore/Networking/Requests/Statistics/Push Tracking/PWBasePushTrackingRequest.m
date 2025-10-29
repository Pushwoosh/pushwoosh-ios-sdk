//
//  PWBasePushTrackingRequest.m
//  Pushwoosh
//
//  Created by Fectum on 25/06/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWBasePushTrackingRequest.h"

@interface PWBasePushTrackingRequest () 

@end

@implementation PWBasePushTrackingRequest

- (instancetype)init {
    if (self = [super init]) {
        self.cacheable = YES;
    }
    return self;
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [self baseDictionary];
    NSString *hash = _pushDict[@"p"];
    
    if (hash != nil) {
        dict[@"hash"] = hash;
    }
    
    return dict;
}


@end
