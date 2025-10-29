//
//  PWCoreUtils.h
//  PushwooshCore
//
//  Created by André Kis on 21.10.25.
//  Copyright © 2025 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PWCoreUtils : NSObject

+ (BOOL)getAPSProductionStatus:(BOOL)canShowAlert;
+ (NSString *)timezone;

@end
