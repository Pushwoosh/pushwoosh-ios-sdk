//
//  PWNetworkModule.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//


#import "PWNetworkModule.h"

@implementation PWNetworkModule

+ (PWNetworkModule*)module {
	static PWNetworkModule *instance = nil;
	static dispatch_once_t pred;
	
	dispatch_once(&pred, ^{
		instance = [PWNetworkModule new];
	});
	
	return instance;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		_requestManager = [PWRequestManager new];
	}
	return self;
}

- (void)inject:(id)object {
	if ([object respondsToSelector:@selector(setRequestManager:)]) {
		[object setRequestManager: self.requestManager];
	}
}

@end
