//
//  PWCombinedSetTagsRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2016
//

#import "PWRequest.h"

#import "PWSetTagsRequest.h"

@interface PWCombinedSetTagsRequest : PWRequest

- (void)addRequest:(PWSetTagsRequest*)request;

@end
