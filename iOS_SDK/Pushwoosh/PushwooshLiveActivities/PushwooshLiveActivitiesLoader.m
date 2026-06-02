/*
 * PushwooshLiveActivitiesLoader.m
 * PushwooshLiveActivities
 *
 * Created by André Kis on 21.05.26.
 * Copyright © 2026 Pushwoosh. All rights reserved.
 *
 * Module verifier rejects Swift `override class func load()` for distribution
 * frameworks, so registration happens from Objective-C `+load`. The Swift
 * implementation class is reached via a forward `@class` declaration — same
 * module, no circular dependency. Wrapped in `TARGET_OS_IOS` /
 * `!TARGET_OS_MACCATALYST` to match the Swift implementation's own guard.
 */

#import <Foundation/Foundation.h>

#if !TARGET_OS_MACCATALYST && TARGET_OS_IOS

#import "PushwooshModuleRegistry.h"
#import "PushwooshModuleIdentifier.h"

@interface PushwooshLiveActivitiesImplementationSetup : NSObject
@end

@interface PushwooshLiveActivitiesLoader : NSObject
@end

@implementation PushwooshLiveActivitiesLoader

+ (void)load {
    if (@available(iOS 16.1, *)) {
        [PushwooshModuleRegistry registerClass:[PushwooshLiveActivitiesImplementationSetup class]
                                 forIdentifier:PWModuleIdentifierLiveActivities];
    }
}

@end

#endif
