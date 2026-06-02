/*
 * PushwooshKeychainLoader.m
 * PushwooshKeychain
 *
 * Created by André Kis on 22.05.26.
 * Copyright © 2026 Pushwoosh. All rights reserved.
 *
 * Module verifier rejects Swift `override class func load()` for distribution
 * frameworks, so registration happens from Objective-C `+load`. The Swift
 * implementation class and back-channel adapter are reached via interface
 * declarations — same module, no circular dependency.
 */

#import <Foundation/Foundation.h>
#import "PushwooshModuleRegistry.h"
#import "PushwooshModuleIdentifier.h"

@interface PushwooshKeychainImplementation : NSObject
@property (class, nonatomic, strong, readonly) id backchannelProvider;
@end

@interface PushwooshKeychainLoader : NSObject
@end

@implementation PushwooshKeychainLoader

+ (void)load {
    Class implClass = [PushwooshKeychainImplementation class];
    [PushwooshModuleRegistry registerClass:implClass
                             forIdentifier:PWModuleIdentifierKeychain];
    id handler = [PushwooshKeychainImplementation backchannelProvider];
    if (handler) {
        [PushwooshModuleRegistry registerHandler:handler
                                   forIdentifier:PWModuleIdentifierKeychain];
    }
}

@end
