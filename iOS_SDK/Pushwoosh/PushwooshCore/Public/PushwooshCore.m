//
//  PushwooshCore.m
//  PushwooshCore
//
//  Created by André Kis on 07.03.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import "PushwooshCore.h"
#import "PWRequestManager.h"
#import "PWNetworkModule.h"

@implementation PushwooshCoreManager

+ (nonnull PWRequestManager *)sharedManager {
    return [[PWNetworkModule module] requestManager];
}

@end
