//
//  PWUnarchiver.m
//  Pushwoosh
//
//  Created by Kiselev Andrey on 21.12.2021.
//  Copyright © 2021 Pushwoosh. All rights reserved.
//

#import "PWUnarchiver.h"

@interface PWUnarchiver ()

@end

@implementation PWUnarchiver

- (id)unarchivedObjectOfClasses:(NSSet<Class> *)classes data:(NSData *)data {
    NSError *error = nil;
    id returnValue = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:data error:&error];
    if (error != nil) {
        PWLogError(@"Deserialization failed: %@", error.localizedDescription);
    }
    return returnValue;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

@end
