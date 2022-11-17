//
//  PWRegisterUserRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2015
//

#import "PWRegisterUserRequest.h"

#if TARGET_OS_IOS || TARGET_OS_WATCH
#import <PWInbox+Internal.h>
#endif

@interface PWRegisterUserRequest () 

@end

@implementation PWRegisterUserRequest

- (instancetype)init {
    if (self = [super init]) {
        self.cacheable = NO;
    }
    return self;
}

- (NSString *)methodName {
	return @"registerUser";
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [self baseDictionary];

	return dict;
}



@end
