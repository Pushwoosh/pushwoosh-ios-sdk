/*
 * PushwooshTVoSLoader.m
 * PushwooshTVOS
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

@interface PushwooshTVOSImplementation : NSObject
@property (class, nonatomic, strong, readonly) id inAppBackchannel;
@end

@interface PushwooshTVoSLoader : NSObject
@end

@implementation PushwooshTVoSLoader

+ (void)load {
    Class implClass = [PushwooshTVOSImplementation class];
    [PushwooshModuleRegistry registerClass:implClass
                             forIdentifier:PWModuleIdentifierTVoS];
    id handler = [PushwooshTVOSImplementation inAppBackchannel];
    if (handler) {
        [PushwooshModuleRegistry registerHandler:handler
                                   forIdentifier:PWModuleIdentifierTVoS];
    }
}

@end
