/*
 * PushwooshInAppLoader.m
 * PushwooshInApp
 *
 * Created by André Kis on 23.06.26.
 * Copyright © 2026 Pushwoosh. All rights reserved.
 *
 * Module verifier rejects Swift `override class func load()` for distribution
 * frameworks, so registration happens from Objective-C `+load`. The Swift
 * implementation class and back-channel adapter are reached via an interface
 * declaration — same module, no circular dependency.
 */

#import <Foundation/Foundation.h>
#import "PushwooshModuleRegistry.h"
#import "PushwooshModuleIdentifier.h"

@interface PushwooshInAppImplementation : NSObject
@property (class, nonatomic, strong, readonly) id configureBackchannel;
@end

@interface PushwooshInAppLoader : NSObject
@end

@implementation PushwooshInAppLoader

+ (void)load {
    Class implClass = [PushwooshInAppImplementation class];
    [PushwooshModuleRegistry registerClass:implClass
                             forIdentifier:PWModuleIdentifierInApp];
    id handler = [PushwooshInAppImplementation configureBackchannel];
    if (handler) {
        [PushwooshModuleRegistry registerHandler:handler
                                   forIdentifier:PWModuleIdentifierInApp];
    }
}

@end
