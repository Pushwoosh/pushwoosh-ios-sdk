//
//  NSDictionary+PWDictUtils.m
//  PushNotificationManager
//
//  Created by Kaizer on 20/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "NSDictionary+PWDictUtils.h"

@implementation NSDictionary (PWDictUtils)

- (id)pw_objectForKey:(id)aKey ofTypes:(NSArray *)types {
	id object = self[aKey];
	for (Class clazz in types) {
		if ([object isKindOfClass:clazz]) {
			return object;
		}
	}
	return nil;
}

- (id)pw_objectForKey:(id)aKey ofType:(Class)type {
	id object = self[aKey];
	if ([object isKindOfClass:type]) {
		return object;
	}
	return nil;
}

- (NSString *)pw_stringForKey:(id)aKey {
	return [self pw_objectForKey:aKey ofType:[NSString class]];
}

- (NSDictionary *)pw_dictionaryForKey:(id)aKey {
	return [self pw_objectForKey:aKey ofType:[NSDictionary class]];
}

- (NSArray *)pw_arrayForKey:(id)aKey {
	return [self pw_objectForKey:aKey ofType:[NSArray class]];
}

- (double)pw_doubleForKey:(id)aKey {
	return [[self pw_objectForKey:aKey ofTypes:@[ [NSString class], [NSNumber class] ]] doubleValue];
}

- (NSNumber *)pw_numberForKey:(id)aKey {
    return [self pw_objectForKey:aKey ofType:[NSNumber class]];
}

- (NSNumber *)pw_forceNumberForKey:(id)aKey {
    NSNumber *result = [self pw_objectForKey:aKey ofType:[NSNumber class]];
    if (result) {
        return result;
    } else {
        NSString *string = [self pw_objectForKey:aKey ofType:[NSString class]];
        if (string) {
            
            return @(string.longLongValue);
        } else {
            return nil;
        }
    }
}

- (NSString *)pw_forceStringForKey:(id)aKey {
    NSString *result = [self pw_objectForKey:aKey ofType:[NSString class]];
    if (result) {
        return result;
    } else {
        NSNumber *result = [self pw_objectForKey:aKey ofType:[NSNumber class]];
        return result.stringValue;
    }
}

@end
