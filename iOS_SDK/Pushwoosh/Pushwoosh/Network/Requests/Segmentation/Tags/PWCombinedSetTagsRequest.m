//
//  PWCombinedSetTagsRequest.m
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import "PWCombinedSetTagsRequest.h"

@interface PWCombinedSetTagsRequest ()

@property (nonatomic, strong) NSMutableArray *requests;

@end

@implementation PWCombinedSetTagsRequest

- (instancetype)init {
	self = [super init];
	if (self) {
		_requests = [NSMutableArray new];
	}
	return self;
}

- (NSString *)methodName {
	return @"setTags";
}

- (void)addRequest:(PWSetTagsRequest *)request {
	@synchronized(_requests) {
		[_requests addObject:request];
	}
}

- (NSDictionary *)requestDictionary {
	NSMutableDictionary *dict = [self baseDictionary];
	NSMutableDictionary *combinedTags = [NSMutableDictionary new];
	for (PWSetTagsRequest *request in _requests) {
		NSDictionary *tags = request.requestDictionary[@"tags"];
		[combinedTags addEntriesFromDictionary:tags];
	}

	dict[@"tags"] = combinedTags;
	return dict;
}

- (void)setHttpCode:(NSInteger)httpCode {
	for (PWSetTagsRequest *request in _requests) {
		request.httpCode = httpCode;
	}
}

@end
