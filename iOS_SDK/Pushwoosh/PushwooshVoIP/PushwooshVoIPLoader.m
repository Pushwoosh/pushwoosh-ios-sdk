/*
 * PushwooshVoIPLoader.m
 * PushwooshVoIP
 *
 * Created by André Kis on 21.05.26.
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

@interface PushwooshVoIPImplementation : NSObject
@property (class, nonatomic, strong, readonly) id configureBackchannel;
@end

@interface PushwooshVoIPLoader : NSObject
@end

@implementation PushwooshVoIPLoader

+ (void)load {
    if (@available(iOS 14.0, *)) {
        Class implClass = [PushwooshVoIPImplementation class];
        [PushwooshModuleRegistry registerClass:implClass
                                 forIdentifier:PWModuleIdentifierVoIP];
        id handler = [PushwooshVoIPImplementation configureBackchannel];
        if (handler) {
            [PushwooshModuleRegistry registerHandler:handler
                                       forIdentifier:PWModuleIdentifierVoIP];
        }
    }
}

@end
