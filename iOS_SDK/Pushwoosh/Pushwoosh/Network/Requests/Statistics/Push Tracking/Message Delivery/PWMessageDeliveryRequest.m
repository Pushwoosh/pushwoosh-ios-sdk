//
//  PWMessageDeliveryRequest.m
//  Pushwoosh
//
//  Created by Fectum on 25/06/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWMessageDeliveryRequest.h"

@interface PWMessageDeliveryRequest () 

@end

@implementation PWMessageDeliveryRequest

- (instancetype)init {
    if (self = [super init]) {
        self.cacheable = YES;
    }
    return self;
}

- (NSString *)methodName {
    return @"messageDeliveryEvent";
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [super requestDictionary].mutableCopy;
    NSString *metadata = self.pushDict[@"md"];
    
    if (metadata != nil) {
        dict[@"metaData"] = metadata;
    }
    
    return dict;
}

@end
