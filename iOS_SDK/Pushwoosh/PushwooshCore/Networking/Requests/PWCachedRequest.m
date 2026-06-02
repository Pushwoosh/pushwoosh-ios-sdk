//
//  PWCachedRequest.m
//  Pushwoosh
//
//  Created by Anton Kaizer on 21.08.17.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "PWCachedRequest.h"

@interface PWCachedRequest ()

@property (nonatomic, strong) NSString *methodName;
@property (nonatomic, strong) NSDictionary *requestDictionary;
@property (nonatomic) NSString *requestIdentifier;

@end

@implementation PWCachedRequest

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (instancetype)initWithRequest:(PWRequest *)request {
    if (self = [super init]) {
        _methodName = request.methodName;
        _requestDictionary = request.requestDictionary;
        _requestIdentifier = request.requestIdentifier;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super init]) {
        _methodName = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"methodName"];
        NSSet *requestDictionaryClasses = [NSSet setWithObjects:
                                           [NSDictionary class],
                                           [NSMutableDictionary class],
                                           [NSArray class],
                                           [NSMutableArray class],
                                           [NSString class],
                                           [NSNumber class],
                                           [NSDate class],
                                           [NSNull class],
                                           [NSData class],
                                           nil];
        _requestDictionary = [aDecoder decodeObjectOfClasses:requestDictionaryClasses forKey:@"requestDictionary"];
        _requestIdentifier = [aDecoder decodeObjectOfClass:[NSString class] forKey:@"requestIdentifier"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_methodName forKey:@"methodName"];
    [aCoder encodeObject:_requestDictionary forKey:@"requestDictionary"];
    [aCoder encodeObject:_requestIdentifier forKey:@"requestIdentifier"];
}

@end
