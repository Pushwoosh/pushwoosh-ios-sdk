//
//  PWGetTagsRequest.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWGetTagsRequest.h"

@interface PWGetTagsRequest () 

@property (nonatomic, copy) NSDictionary *tags;

@end

@implementation PWGetTagsRequest

- (NSString *)methodName {
	return @"getTags";
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [self baseDictionary];
	return dict;
}

- (void)parseResponse:(NSDictionary *)response {
	if ([response isKindOfClass:[NSDictionary class]]) {
		NSDictionary *tags = response[@"result"];
		if ([tags isKindOfClass:[NSDictionary class]])
			self.tags = tags;
	}
}

@end
