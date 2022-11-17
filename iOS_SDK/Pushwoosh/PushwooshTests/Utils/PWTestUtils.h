//
//  PWTestUtils.h
//  PushNotificationManager
//
//  Created by Dmitry Malugin on 06/12/16.
//  Copyright © 2016 Pushwoosh. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PWTestUtils : NSObject

+ (void)setUp;

+ (void)tearDown;

+ (void)writeCacheTags:(id)tags;

+ (void)mockStaticMethodForClass:(Class)clazz selector:(SEL)selector block:(id)block;

@end
