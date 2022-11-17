//
//  PWUtils.h
//  PushNotificationManager
//
//  Created by Kaizer on 07/06/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import "PWUtils.common.h"

@interface PWUtils : PWUtilsCommon

+ (BOOL)isValidHwid:(NSString*)hwid;

+ (BOOL)isValidUserId:(NSString*)userId;

@end
