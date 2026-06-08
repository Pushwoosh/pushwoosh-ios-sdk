//
//  PWPushStatRequest
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWPushStatRequest.h"

@interface PWPushStatRequest () 

@end

@implementation PWPushStatRequest

- (NSString *)methodName {
	return @"pushStat";
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
