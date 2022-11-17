//
//  PWCachedRequest.h
//  Pushwoosh
//
//  Created by Anton Kaizer on 21.08.17.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWRequest.h"

@interface PWCachedRequest : PWRequest<NSSecureCoding>

- (NSString *)methodName;
- (NSDictionary *)requestDictionary;
- (NSString *)requestIdentifier;

- (instancetype)initWithRequest:(PWRequest *)request;

@end
