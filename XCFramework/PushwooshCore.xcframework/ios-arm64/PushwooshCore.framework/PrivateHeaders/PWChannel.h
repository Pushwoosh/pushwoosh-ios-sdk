//
//  PWChannel.h
//  Pushwoosh
//
//  Created by Anton Kaizer on 27/09/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PWChannel : NSObject

@property (nonatomic, readonly) NSString *code;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSInteger position;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

@end
