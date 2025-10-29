//
//  PWGetTagsRequest.h
//  Pushwoosh SDK
//  (c) Pushwoosh 2012
//

#import "PWRequest.h"

@interface PWGetTagsRequest : PWRequest

@property (nonatomic, copy, readonly) NSDictionary* tags;

@end
