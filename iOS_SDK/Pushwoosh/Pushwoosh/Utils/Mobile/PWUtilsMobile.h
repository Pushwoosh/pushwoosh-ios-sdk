//
//  PWUtilsMobile.h
//  Pushwoosh
//
//  Created by Fectum on 22/07/2019.
//  Copyright © 2019 Pushwoosh. All rights reserved.
//

#import "PWUtils.common.h"

@interface PWUtilsMobile : PWUtilsCommon

+ (BOOL)isSimulator;

+ (void)stopBackgroundTask:(NSNumber *)taskId;
+ (NSNumber *)startBackgroundTask;


@end

