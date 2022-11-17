//
//  PWRemoveLocationRequest.m
//  Pushwoosh
//
//  Created by Victor Eysner on 01/09/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWRemoveLocationRequest.h"

@implementation PWRemoveLocationRequest

- (NSString *)methodName {
    return @"getNearestZone";
}

- (NSDictionary *)requestDictionary {
    NSMutableDictionary *dict = [self baseDictionary];
    
    dict[@"lat"] = [NSNull null];
    dict[@"lng"] = [NSNull null];
    dict[@"more"] = @(1);
    
    return dict;
}

@end
