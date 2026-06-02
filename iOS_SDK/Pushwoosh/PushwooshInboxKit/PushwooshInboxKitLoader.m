/*
 * PushwooshInboxKitLoader.m
 * PushwooshInboxKit
 *
 * Created by André Kis on 21.05.26.
 * Copyright © 2026 Pushwoosh. All rights reserved.
 *
 * Module verifier rejects Swift `override class func load()` for distribution
 * frameworks, so registration happens from Objective-C `+load`. The Swift
 * implementation class is reached via a forward `@class` declaration — same
 * module, no circular dependency.
 */

#import <Foundation/Foundation.h>
#import "PushwooshModuleRegistry.h"
#import "PushwooshModuleIdentifier.h"

@interface PushwooshInboxKitImplementation : NSObject
@end

@interface PushwooshInboxKitLoader : NSObject
@end

@implementation PushwooshInboxKitLoader

+ (void)load {
    [PushwooshModuleRegistry registerClass:[PushwooshInboxKitImplementation class]
                             forIdentifier:PWModuleIdentifierInboxKit];
}

@end
