//
//  PWCoreUtils.m
//  PushwooshCore
//
//  Created by André Kis on 21.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <PushwooshCore/PWCoreUtils.h>
#import "PWUtils.common.h"

@implementation PWCoreUtils

+ (BOOL)getAPSProductionStatus:(BOOL)canShowAlert {
    return [PWUtilsCommon getAPSProductionStatus:canShowAlert];
}

+ (NSString *)timezone {
    return [PWUtilsCommon timezone];
}

@end
