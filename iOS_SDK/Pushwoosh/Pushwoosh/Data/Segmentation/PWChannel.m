//
//  PWChannel.m
//  Pushwoosh
//
//  Created by Anton Kaizer on 27/09/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWChannel.h"
#import "NSDictionary+PWDictUtils.h"

@interface PWChannel()

@property (nonatomic, readwrite) NSString *code;
@property (nonatomic, readwrite) NSString *name;
@property (nonatomic, readwrite) NSInteger position;

@end

@implementation PWChannel

- (instancetype)initWithDictionary:(NSDictionary *)dictionary {
    if (self = [super init]) {
        _code = [dictionary pw_stringForKey:@"code"];
        _name = [dictionary pw_stringForKey:@"name"];
        _position = [[dictionary pw_numberForKey:@"position"] integerValue];
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"code" : _code,
        @"name" : _name,
        @"position" : @(_position)
    };
}

@end
