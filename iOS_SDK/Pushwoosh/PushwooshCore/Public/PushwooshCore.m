//
//  PushwooshCore.m
//  PushwooshCore
//
//  Created by André Kis on 07.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PushwooshCore.h"

@implementation PushwooshCoreManager

static id<IPWCoreRequestManager> _sharedManager;

+ (nonnull id<IPWCoreRequestManager>)sharedManager {
    if (!_sharedManager) {
        return PWCoreRequestManager.sharedManager;
    }
    return _sharedManager;
}

@end
