//
//  PWSetTagsRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRequest.h"

@interface PWSetTagsRequest : PWRequest

@property (nonatomic, retain) NSDictionary *tags;

/// Tags in the form the server accepts: dates as strings, `#pwinc#` increments, values JSON cannot carry dropped.
+ (NSDictionary *)sanitizedTags:(NSDictionary *)tags;

@end
