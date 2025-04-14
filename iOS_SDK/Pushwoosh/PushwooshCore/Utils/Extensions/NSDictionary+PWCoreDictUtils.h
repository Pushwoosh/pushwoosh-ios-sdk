//
//  NSDictionary+PWCoreDictUtils.h
//  PushwooshCore
//
//  Created by André Kis on 12.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDictionary (PWCoreDictUtils)

- (id)pw_objectForKey:(id)aKey ofTypes:(NSArray *)types;
- (id)pw_objectForKey:(id)aKey ofType:(Class)type;

- (NSString *)pw_stringForKey:(id)aKey;
- (NSDictionary *)pw_dictionaryForKey:(id)aKey;
- (NSArray *)pw_arrayForKey:(id)aKey;
- (double)pw_doubleForKey:(id)aKey;
- (NSNumber *)pw_numberForKey:(id)aKey;
- (NSNumber *)pw_forceNumberForKey:(id)aKey;
- (NSString *)pw_forceStringForKey:(id)aKey;

@end

NS_ASSUME_NONNULL_END
