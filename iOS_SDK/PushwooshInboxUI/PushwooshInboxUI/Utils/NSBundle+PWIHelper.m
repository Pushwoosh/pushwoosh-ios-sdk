//
//  NSBundle+PWIHelper.m
//  PushwooshInboxUI
//
//  Created by Pushwoosh on 17/11/2017.
//  Copyright © 2017 Pushwoosh. All rights reserved.
//

#import "NSBundle+PWIHelper.h"

@implementation NSBundle (PWIHelper)

+ (NSBundle *)pwi_bundleForClass:(Class)aClass {
    NSBundle *bundle = [NSBundle bundleWithIdentifier:@"com.pushwoosh.PushwooshInboxBundle"];
    
    if (!bundle) {
        NSString *resourceBundlePath = [[NSBundle mainBundle] pathForResource:@"PushwooshInboxBundle" ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:resourceBundlePath];
    }
    
    if (!bundle) {
        bundle = [NSBundle bundleForClass:aClass];
    }
    
    return bundle;
}

@end
