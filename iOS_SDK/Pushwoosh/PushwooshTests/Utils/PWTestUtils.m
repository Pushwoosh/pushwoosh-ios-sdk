//
//  PWTestUtils.m
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 06/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PushNotificationManager.h"
#import "Pushwoosh+Internal.h"
#import "PWInAppStorage.h"
#import "PWCache.h"
#import "PWPreferences.h"
#import "PWInAppManager.h"
#import "PWInAppManager+Internal.h"
#import "PWUtils.h"

#import "PWTestUtils.h"
#import <objc/runtime.h>

static NSString * cacheFile() {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *cacheDir = [paths objectAtIndex:0];
	return [cacheDir stringByAppendingPathComponent:@"pwtags"];
}

@implementation PWTestUtils

+ (void)setUp {
	// setup pushwoosh testing
}

+ (void)tearDown {
	// Clear pushwoosh globals
	[Pushwoosh destroy];
	[PWInAppManager destroy];
	
	[PWInAppStorage destroy];
	[[PWCache cache] clear];
	[PWPreferences preferences].appCode = nil;
	[PWPreferences preferences].appName = nil;
	[PWPreferences preferences].pushToken = nil;
	[PWPreferences preferences].userId = [PWPreferences preferences].hwid;
	[PWPreferences preferences].lastRegTime = nil;
	[PWPreferences preferences].categories = nil;
	[PWPreferences preferences].baseUrl = [[PWPreferences preferences] defaultBaseUrl];
}

+ (void)writeCacheTags:(id)tags {
    if (TARGET_OS_IOS && [PWUtils isSystemVersionGreaterOrEqualTo:@"11.0"]) {
        NSError *error = nil;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:tags requiringSecureCoding:YES error:&error];
        [data writeToFile:cacheFile() options:NSDataWritingAtomic error:&error];
    } else {
        [NSKeyedArchiver archiveRootObject:tags toFile:cacheFile()];
    }
}

+ (void)mockStaticMethodForClass:(Class)clazz selector:(SEL)selector block:(id)block {
    Method m = class_getClassMethod(clazz, selector);
    IMP block_imp = imp_implementationWithBlock(block);
    method_setImplementation(m, block_imp);
}

@end
