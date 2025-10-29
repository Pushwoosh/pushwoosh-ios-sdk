//
//  NSDictionary+PWDictUtils.h
//  PushNotificationManager
//
//  Created by Kaizer on 20/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary (PWDictUtils)

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
