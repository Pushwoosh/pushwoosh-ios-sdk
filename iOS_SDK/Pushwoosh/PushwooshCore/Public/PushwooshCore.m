//
//  PushwooshCore.m
//  PushwooshCore
//
//  Created by André Kis on 07.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PushwooshCore.h"
#import "PWRequestManager.h"

@implementation PushwooshCoreManager

static PWRequestManager *_sharedManager;

+ (nonnull PWRequestManager *)sharedManager {
    if (!_sharedManager) {
        _sharedManager = [[PWRequestManager alloc] init];
    }
    return _sharedManager;
}

@end
